terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/ecr/aws?version=3.2.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  repository_name = "placeholder"

  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true
  repository_force_delete         = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images older than count"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
