include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/iam.hcl"
  expose = true
}

locals {
  aws_region         = "us-east-1"
  source_bucket_name = "${include.envcommon.locals.account_id}-${local.aws_region}-data-source-${include.envcommon.locals.environment}"
  dest_bucket_name   = "${include.envcommon.locals.account_id}-us-east-2-data-source-${include.envcommon.locals.environment}"
  source_bucket_arn  = "arn:aws:s3:::${local.source_bucket_name}"
  dest_bucket_arn    = "arn:aws:s3:::${local.dest_bucket_name}"
}

inputs = merge(
  include.envcommon.inputs,
  {
    name                 = "s3-replication-${include.envcommon.locals.environment}-${local.aws_region}"
    use_name_prefix      = false
    description          = "IAM role for S3 cross-region replication"
    create_inline_policy = true

    trust_policy_permissions = {
      S3ServiceTrust = {
        actions = ["sts:AssumeRole"]
        principals = [{
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        }]
      }
    }

    inline_policy_permissions = {
      SourceBucketRead = {
        actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        resources = [local.source_bucket_arn]
      }
      SourceObjectRead = {
        actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        resources = ["${local.source_bucket_arn}/*"]
      }
      DestObjectWrite = {
        actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        resources = ["${local.dest_bucket_arn}/*"]
      }
    }
  }
)
