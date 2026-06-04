include {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vpc.hcl"
  expose         = true
}

locals {
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}

inputs = merge(
  include.envcommon.inputs,
  {
    cidr            = local.vpc_cidr
    azs             = local.azs
    private_subnets = local.private_subnets
    public_subnets  = local.public_subnets
  }
)