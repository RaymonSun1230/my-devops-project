terraform {
  source = "tfr:///terraform-aws-modules/acm/aws?version=~> 5.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  domain_name               = "cloudnativeops.online"
  subject_alternative_names = ["www.cloudnativeops.online"]

  validation_method = "DNS"

  create_route53_records = false

  tags = {
    ManagedBy = "Terragrunt"
  }
}
