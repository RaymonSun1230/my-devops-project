include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/acm.hcl"
  expose = true
}

inputs = {
  domain_name               = "cloudnativeops.online"
  subject_alternative_names = ["www.cloudnativeops.online"]
}
