include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/s3-data-source.hcl"
  expose = true
}

inputs = merge(
  include.envcommon.inputs,
  {}
)
