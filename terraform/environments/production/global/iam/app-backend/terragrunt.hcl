include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/iam-service-accounts.hcl"
  expose = true
}

dependency "eks_us_east_1" {
  config_path = "../../../us-east-1/eks"
}

dependency "eks_us_east_2" {
  config_path = "../../../us-east-2/eks"
}

dependency "s3_us_east_1" {
  config_path = "../../../us-east-1/s3/data-source"
}

dependency "s3_us_east_2" {
  config_path = "../../../us-east-2/s3/data-source"
}

inputs = merge(
  include.envcommon.inputs,
  {
    name = "app-backend-${include.envcommon.locals.environment}"

    assume_role_condition_test = "StringLike"

    oidc_providers = {
      us_east_1 = {
        provider_arn               = dependency.eks_us_east_1.outputs.oidc_provider_arn
        namespace_service_accounts = ["myapp:backend"]
      }
      us_east_2 = {
        provider_arn               = dependency.eks_us_east_2.outputs.oidc_provider_arn
        namespace_service_accounts = ["myapp:backend"]
      }
    }

    create_inline_policy = true

    inline_policy_permissions = {
      S3ReadUsEast1 = {
        actions = ["s3:GetObject", "s3:ListBucket"]
        resources = [
          dependency.s3_us_east_1.outputs.s3_bucket_arn,
          "${dependency.s3_us_east_1.outputs.s3_bucket_arn}/*"
        ]
      }
      S3ReadUsEast2 = {
        actions = ["s3:GetObject", "s3:ListBucket"]
        resources = [
          dependency.s3_us_east_2.outputs.s3_bucket_arn,
          "${dependency.s3_us_east_2.outputs.s3_bucket_arn}/*"
        ]
      }
    }
  }
)
