terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/eks/aws?version=21.23.0"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
}

inputs = {
  name                                     = "demo-app-${local.environment}"
  kubernetes_version                       = "1.35"
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    admin = {
      principal_arn = "arn:aws:iam::385551094956:user/Raymon-PowerUser"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # EKS addons
  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }

  create_security_group      = true
  create_node_security_group = true

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    group = {
      name         = "demo-app-ng"
      desired_size = 4
      max_size     = 5
      min_size     = 1

      capacity_type  = "ON_DEMAND"
      instance_types = ["t4g.small"]

      ami_type = "AL2023_ARM_64_STANDARD"

      block_device_maps = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      ]

      tags = {
        Environment = local.environment
      }
    }
  }

  tags = {
    Environment = local.environment
  }
}