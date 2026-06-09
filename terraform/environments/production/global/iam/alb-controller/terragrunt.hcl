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
    name = "lb-controller-${include.envcommon.locals.environment}"

    attach_load_balancer_controller_policy = true

    oidc_providers = {
      us_east_1 = {
        provider_arn               = dependency.eks_us_east_1.outputs.oidc_provider_arn
        namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
      }
      us_east_2 = {
        provider_arn               = dependency.eks_us_east_2.outputs.oidc_provider_arn
        namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
      }
    }
  }
)
