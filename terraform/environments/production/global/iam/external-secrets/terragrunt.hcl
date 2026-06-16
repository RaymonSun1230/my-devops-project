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

inputs = merge(
  include.envcommon.inputs,
  {
    name = "external-secrets-${include.envcommon.locals.environment}"

    oidc_providers = {
      us_east_1 = {
        provider_arn               = dependency.eks_us_east_1.outputs.oidc_provider_arn
        namespace_service_accounts = ["external-secrets:external-secrets"]
      }
      us_east_2 = {
        provider_arn               = dependency.eks_us_east_2.outputs.oidc_provider_arn
        namespace_service_accounts = ["external-secrets:external-secrets"]
      }
    }

    create_inline_policy = true

    inline_policy_permissions = {
      SecretsManagerRead = {
        actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        resources = ["arn:aws:secretsmanager:*:*:secret:grafana-admin-*"]
      }
    }
  }
)
