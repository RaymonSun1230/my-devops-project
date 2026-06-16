terraform {
  source = "tfr:///terraform-aws-modules/wafv2/aws?version=~> 2.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
}

inputs = {
  name = "waf-webacl-${local.environment}-${local.aws_region}"

  scope          = "REGIONAL"
  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-webacl-${local.environment}"
    sampled_requests_enabled   = true
  }

  rules = {
    common-rule-set = {
      priority        = 1
      override_action = "none"

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "waf-common-${local.environment}"
        sampled_requests_enabled   = true
      }
    }

    ip-reputation = {
      priority        = 2
      override_action = "none"

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "waf-ip-rep-${local.environment}"
        sampled_requests_enabled   = true
      }
    }

    known-bad-inputs = {
      priority        = 3
      override_action = "none"

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "waf-bad-inputs-${local.environment}"
        sampled_requests_enabled   = true
      }
    }

    rate-limit = {
      priority = 4
      action   = "block"

      statement = {
        rate_based_statement = {
          limit              = 2000
          aggregate_key_type = "IP"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "waf-rate-${local.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  tags = {
    ManagedBy   = "Terragrunt"
    Environment = local.environment
  }
}
