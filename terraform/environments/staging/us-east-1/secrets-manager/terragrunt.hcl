include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/secrets-manager.hcl"
  expose = true
}

dependency "kms" {
  config_path = "../kms"
}

inputs = merge(
  include.envcommon.inputs,
  {
    recovery_window_in_days = 7
    kms_key_id              = dependency.kms.outputs.key_arn
  }
)
