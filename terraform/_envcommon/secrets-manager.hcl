terraform {
  source = "tfr:///terraform-aws-modules/secrets-manager/aws?version=~> 2.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  name = "grafana-admin-${local.environment}"

  description = "Grafana admin password for ${local.environment} environment"

  create_random_password = true
  random_password_length = 24

  recovery_window_in_days = 30

  tags = {
    ManagedBy   = "Terragrunt"
    Environment = local.environment
  }
}
