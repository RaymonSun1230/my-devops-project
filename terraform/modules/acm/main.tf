terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }
}

variable "domain_name" {
  description = "Domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "SANs for the certificate (e.g. www.domain.com)"
  type        = list(string)
  default     = []
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = var.domain_name
    ManagedBy = "Terragrunt"
  }
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.this.arn
}

output "validation_options" {
  description = "ACM DNS validation options (for Route53 records)"
  value       = aws_acm_certificate.this.domain_validation_options
}

output "domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.this.domain_name
}
