terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/s3-bucket/aws?version=4.6.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
  account_id  = local.environment_vars.locals.aws_account_id
}

inputs = {
  bucket = "${local.account_id}-${local.aws_region}-data-source-${local.environment}"

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
