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

inputs = merge(
  include.envcommon.inputs,
  {
    name = "lb-controller-${include.envcommon.locals.environment}"

    attach_load_balancer_controller_policy = true

    oidc_providers = {
      main = {
        provider_arn               = dependency.eks.outputs.oidc_provider_arn
        namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
      }
    }
  }
)
