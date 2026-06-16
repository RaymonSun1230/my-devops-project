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
      rate-limit = {
        priority = 4
        action   = "block"
        statement = {
          rate_based_statement = {
            limit              = 500
            aggregate_key_type = "IP"
          }
        }
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "waf-rate-dev"
          sampled_requests_enabled   = true
        }
      }
    }
  )
}
