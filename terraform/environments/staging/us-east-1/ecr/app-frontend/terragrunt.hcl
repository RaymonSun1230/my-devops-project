include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/ecr.hcl"
  expose = true
}

dependency "kms" {
  config_path = "../kms"
}

inputs = merge(
  include.envcommon.inputs,
  {
    repository_name = "app-frontend"
    kms_key_arn     = dependency.kms.outputs.key_arn
  }
)
