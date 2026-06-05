terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/vpc/aws?version=6.6.1"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  name = "myapp-${local.environment}-vpc"

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log = false

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}