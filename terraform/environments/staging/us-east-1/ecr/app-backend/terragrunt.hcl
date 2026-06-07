include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/ecr.hcl"
  expose = true
}

inputs = merge(
  include.envcommon.inputs,
  {
    repository_name = "app-backend"
  }
)
