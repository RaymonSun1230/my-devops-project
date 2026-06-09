terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-role?version=6.6.1"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  environment = local.environment_vars.locals.environment
  account_id  = local.environment_vars.locals.aws_account_id
}

inputs = {
  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
