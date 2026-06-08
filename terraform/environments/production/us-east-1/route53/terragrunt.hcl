include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/route53.hcl"
  expose = true
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//route53"
}

locals {
  # Hard-code ALB DNS/zone IDs from the deployed production ALBs.
  # These are outputs from the ingress controller — update after ALB is created.
  primary_alb_dns     = "k8s-myapp-frontend-a0da1ec5d1-48248821.us-east-1.elb.amazonaws.com"
  primary_alb_zone_id = "Z35SXDOTRQ7X7K" # us-east-1 ALB canonical zone ID

  secondary_alb_dns     = "k8s-myapp-frontend-yyyyyyyyyy-987654321.us-east-2.elb.amazonaws.com"
  secondary_alb_zone_id = "Z3AADJGX6KTTL2" # us-east-2 ALB canonical zone ID
}

dependency "acm_primary" {
  config_path = "../acm"
}

dependency "acm_secondary" {
  config_path = "../../us-east-2/acm"
}

inputs = merge(
  include.envcommon.inputs,
  {
    domain_name                      = "cloudnativeops.online"
    aws_region_primary               = "us-east-1"
    aws_region_secondary             = "us-east-2"
    primary_alb_dns                  = local.primary_alb_dns
    primary_alb_zone_id              = local.primary_alb_zone_id
    secondary_alb_dns                = local.secondary_alb_dns
    secondary_alb_zone_id            = local.secondary_alb_zone_id
    acm_validation_options_primary   = dependency.acm_primary.outputs.validation_options
    acm_validation_options_secondary = dependency.acm_secondary.outputs.validation_options
  }
)
