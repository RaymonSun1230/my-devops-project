include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/s3-data-source.hcl"
  expose = true
}

inputs = merge(
  include.envcommon.inputs,
  {
    bucket = "${include.envcommon.locals.account_id}-${include.envcommon.locals.aws_region}-data-source-${include.envcommon.locals.environment}"
  }
)
