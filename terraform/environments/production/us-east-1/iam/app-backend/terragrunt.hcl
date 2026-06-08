include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/iam.hcl"
  expose = true
}

dependency "eks" {
  config_path = "../../eks"
}

dependency "s3" {
  config_path = "../../s3/data-source"
}

inputs = merge(
  include.envcommon.inputs,
  {
    role_name = "app-backend-${include.envcommon.locals.environment}"

    assume_role_condition_test = "StringLike"

    oidc_providers = {
      main = {
        provider_arn               = dependency.eks.outputs.oidc_provider_arn
        namespace_service_accounts = ["myapp:backend"]
      }
    }

    inline_policies = {
      S3DataSourceRead = {
        policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:ListBucket"
              ]
              Resource = [
                dependency.s3.outputs.s3_bucket_arn,
                "${dependency.s3.outputs.s3_bucket_arn}/*"
              ]
            }
          ]
        })
      }
    }
  }
)
