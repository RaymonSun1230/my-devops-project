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
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
