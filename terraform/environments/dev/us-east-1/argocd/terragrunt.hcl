include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/argocd.hcl"
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

inputs = merge(
  include.envcommon.inputs,
  {}
)
