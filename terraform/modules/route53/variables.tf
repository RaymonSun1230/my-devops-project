variable "domain_name" {
  description = "The domain name for the Route53 hosted zone"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. production)"
  type        = string
}

variable "aws_region_primary" {
  description = "Primary AWS region (us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_secondary" {
  description = "Secondary AWS region for DR (us-east-2)"
  type        = string
  default     = "us-east-2"
}

variable "primary_alb_dns" {
  description = "DNS name of the primary region ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID of the primary region ALB"
  type        = string
}

variable "secondary_alb_dns" {
  description = "DNS name of the secondary region ALB"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Zone ID of the secondary region ALB"
  type        = string
}

variable "acm_validation_options_primary" {
  description = "ACM certificate validation options from the primary region cert"
  type = list(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
  default = []
}

variable "acm_validation_options_secondary" {
  description = "ACM certificate validation options from the secondary region cert"
  type = list(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
  default = []
}
