include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/s3.hcl"
  expose = true
}

dependency "s3_dest" {
  config_path = "../../../us-east-2/s3/data-source"
}

dependency "iam_s3_replication" {
  config_path = "../../../global/iam/s3-replication"
}

dependency "kms" {
  config_path = "../kms"
}

inputs = merge(
  include.envcommon.inputs,
  {
    bucket = "${include.envcommon.locals.account_id}-${include.envcommon.locals.aws_region}-data-source-${include.envcommon.locals.environment}"

    versioning = {
      status = true
    }

    server_side_encryption_configuration = {
      rule = {
        apply_server_side_encryption_by_default = {
          sse_algorithm     = "aws:kms"
          kms_master_key_id = dependency.kms.outputs.key_arn
        }
      }
    }

    replication_configuration = {
      role = dependency.iam_s3_replication.outputs.arn
      rules = [
        {
          id       = "cross-region-replication"
          status   = "Enabled"
          priority = 1

          destination = {
            bucket        = dependency.s3_dest.outputs.s3_bucket_arn
            storage_class = "STANDARD"
          }

          delete_marker_replication_status = "Enabled"
        }
      ]
    }
  }
)
