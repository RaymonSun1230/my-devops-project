# Route53 Multi-Region DNS Module
# Handles: hosted zone, health checks, failover DNS records

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }
}

# ------------------------------------------------------------
# Route53 Hosted Zone
# ------------------------------------------------------------
resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    Environment = var.environment
    ManagedBy   = "Terragrunt"
  }
}

# ------------------------------------------------------------
# Health Checks for ALB endpoints
# ------------------------------------------------------------
resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name        = "${var.environment}-primary-${var.aws_region_primary}"
    Environment = var.environment
    ManagedBy   = "Terragrunt"
  }
}

resource "aws_route53_health_check" "secondary" {
  fqdn              = var.secondary_alb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name        = "${var.environment}-secondary-${var.aws_region_secondary}"
    Environment = var.environment
    ManagedBy   = "Terragrunt"
  }
}

# ------------------------------------------------------------
# Failover DNS Records (A records with Alias to ALB)
# ------------------------------------------------------------
resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "${var.environment}-primary-${var.aws_region_primary}"
}

resource "aws_route53_record" "frontend_secondary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.secondary_alb_dns
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "${var.environment}-secondary-${var.aws_region_secondary}"
}

# ------------------------------------------------------------
# ACM DNS validation records (created after zone exists)
# ------------------------------------------------------------
resource "aws_route53_record" "acm_validation_primary" {
  for_each = {
    for dvo in var.acm_validation_options_primary : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

resource "aws_route53_record" "acm_validation_secondary" {
  for_each = {
    for dvo in var.acm_validation_options_secondary : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

# ------------------------------------------------------------
# Optional: WWW subdomain redirect record
# ------------------------------------------------------------
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "${var.environment}-www-primary-${var.aws_region_primary}"
}
