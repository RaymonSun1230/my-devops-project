terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//route53"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  environment = local.environment
}
