include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/waf.hcl"
  expose = true
}

inputs = {
  rules = merge(
    include.envcommon.inputs.rules,
    {
      sql-injection = {
        priority = 5
        action   = "block"

        statement = {
          managed_rule_group_statement = {
            name        = "AWSManagedRulesSQLiRuleSet"
            vendor_name = "AWS"
          }
        }

        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "waf-sqli-prod"
          sampled_requests_enabled   = true
        }
      }
    }
  )
}
