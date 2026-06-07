terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//argocd"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  region      = local.region_vars.locals.aws_region
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "placeholder"
  }
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  region       = local.region
  namespace    = "argocd"

  helm_values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        extraArgs = ["--insecure"]
      }
      crds = {
        install = true
      }
    })
  ]
}
