include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks.hcl"
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = merge(
  include.envcommon.inputs,
  {
    vpc_id     = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnets
  }
)
