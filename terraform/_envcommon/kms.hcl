terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/kms/aws?version=~> 3.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
  account_id  = local.environment_vars.locals.aws_account_id
}

inputs = {
  description = "KMS key for ${local.environment} environment in ${local.aws_region}"

  deletion_window_in_days = 30
  enable_key_rotation     = true

  aliases = ["s3-${local.environment}-${local.aws_region}"]

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
