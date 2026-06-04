locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  aws_region     = local.region_vars.locals.aws_region
  environment    = local.environment_vars.locals.environment
  aws_account_id = local.environment_vars.locals.aws_account_id
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"
    }
  EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket       = "${local.aws_account_id}-${local.aws_region}-tfstates-bucket"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.environment_vars.locals,
  local.region_vars.locals
)