include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/s3.hcl"
  expose = true
}

dependency "kms" {
  config_path = "../kms"
}

inputs = merge(
  include.envcommon.inputs,
  {
    bucket = "${include.envcommon.locals.account_id}-${include.envcommon.locals.aws_region}-data-source-${include.envcommon.locals.environment}"

    server_side_encryption_configuration = {
      rule = {
        apply_server_side_encryption_by_default = {
          sse_algorithm     = "aws:kms"
          kms_master_key_id = dependency.kms.outputs.key_arn
        }
      }
    }
  }
)
