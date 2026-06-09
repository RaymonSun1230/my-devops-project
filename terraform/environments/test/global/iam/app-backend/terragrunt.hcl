include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/iam-service-accounts.hcl"
  expose = true
}

dependency "eks" {
  config_path = "../../../us-east-1/eks"
}

dependency "s3" {
  config_path = "../../../us-east-1/s3/data-source"
}

inputs = merge(
  include.envcommon.inputs,
  {
    name = "app-backend-${include.envcommon.locals.environment}"

    assume_role_condition_test = "StringLike"

    oidc_providers = {
      main = {
        provider_arn               = dependency.eks.outputs.oidc_provider_arn
        namespace_service_accounts = ["myapp:backend"]
      }
    }

    create_inline_policy = true

    inline_policy_permissions = {
      S3Read = {
        actions = ["s3:GetObject", "s3:ListBucket"]
        resources = [
          dependency.s3.outputs.s3_bucket_arn,
          "${dependency.s3.outputs.s3_bucket_arn}/*"
        ]
      }
    }
  }
)
