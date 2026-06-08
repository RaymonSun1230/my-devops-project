# Infrastructure as Code (Terragrunt + Terraform)

> Part of [My DevOps Project](../README.md) — detailed documentation.

---

## Overview

All AWS infrastructure is provisioned with **Terragrunt** (a thin wrapper around Terraform) using the **DRY** principle — shared configurations live in `_envcommon/` and are included by each environment.

---

## Provisioned Resources

| Resource | Module Source | Details |
|----------|--------------|---------|
| **VPC** | `terraform-aws-modules/vpc/aws` (6.6.1) | Public + private subnets, NAT Gateway, DNS hostnames |
| **EKS** | `terraform-aws-modules/eks/aws` (21.23.0) | Kubernetes 1.35, managed node groups (t4g.small, ARM64), IRSA enabled |
| **ECR** | `terraform-aws-modules/ecr/aws` (3.2.0) | Per-app repositories, lifecycle policy (keep last 50 images) |
| **S3** | `terraform-aws-modules/s3-bucket/aws` (4.6.0) | Data source bucket per environment |
| **IAM (IRSA)** | `terraform-aws-modules/iam/aws` (6.6.1) | Roles for ALB Controller, Backend S3 access, GitHub Actions OIDC |
| **Argo CD** | Custom module (`modules/argocd`) | Helm-deployed Argo CD with EKS authentication |

---

## Terragrunt DRY Pattern

```
terraform/
├── root.hcl                    # Provider gen + remote state (auto-included)
├── _envcommon/                 # Environment-agnostic module configs
│   ├── vpc.hcl                 #   terraform source + default inputs
│   ├── eks.hcl                 #   cluster config + node groups
│   ├── ecr.hcl                 #   repo + lifecycle policy
│   ├── iam.hcl                 #   IRSA role template
│   ├── s3.hcl                  #   bucket config
│   └── argocd.hcl              #   ArgoCD Helm deployment
├── modules/
│   └── argocd/                 #   Custom Terraform module
│       ├── main.tf             #     helm_release for argo-cd
│       ├── variables.tf
│       └── outputs.tf
└── environments/               # Per-environment overrides
    ├── dev/
    │   └── us-east-1/
    │       ├── vpc/terragrunt.hcl      # include envcommon + override CIDRs
    │       ├── eks/terragrunt.hcl
    │       ├── ecr/app-backend/terragrunt.hcl
    │       ├── ecr/app-frontend/terragrunt.hcl
    │       ├── iam/alb-controller/terragrunt.hcl
    │       ├── iam/app-backend/terragrunt.hcl
    │       ├── s3/data-source/terragrunt.hcl
    │       └── argocd/terragrunt.hcl
    ├── test/
    ├── staging/
    ├── perf/
    └── production/
        ├── us-east-1/
        └── us-east-2/
```

### How it works

1. `root.hcl` auto-generates the AWS provider and S3 remote state backend
2. `_envcommon/<resource>.hcl` defines the terraform source, default inputs
3. Each environment's `terragrunt.hcl` includes the envcommon and overrides only what differs

Example VPC override:

```hcl
# terraform/environments/production/us-east-1/vpc/terragrunt.hcl
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vpc.hcl"
  expose = true
}

locals {
  vpc_cidr        = "10.10.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24"]
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
```

---

## Environment Configuration

Each environment defines two files:

### `environment.hcl`

```hcl
# terraform/environments/dev/environment.hcl
locals {
  aws_account_id = "385551094956"
  environment    = "dev"
}
```

### `region.hcl`

```hcl
# terraform/environments/dev/us-east-1/region.hcl
locals {
  aws_region = "us-east-1"
}
```

---

## Remote State

All Terraform state is stored in S3 with DynamoDB locking per environment:

```
s3://{account_id}-{region}-tfstates-bucket/{path}/terraform.tfstate
```

Generated automatically by `root.hcl`:

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket       = "${local.aws_account_id}-${local.aws_region}-tfstates-bucket"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}
```

---

## Provisioning Order

Resources are provisioned in dependency order:

```
1. VPC          (no dependencies)
2. EKS          (depends on VPC)
3. ECR          (no dependencies)
4. S3           (no dependencies)
5. IAM          (depends on EKS — needs OIDC provider)
6. ArgoCD       (depends on EKS)
```

```bash
# Plan all resources
cd terraform/environments/dev/us-east-1
terragrunt run-all plan

# Apply all resources
terragrunt run-all apply

# Apply a specific module
cd terraform/environments/dev/us-east-1/eks
terragrunt apply
```

---

## EKS Cluster Configuration

```hcl
# terraform/_envcommon/eks.hcl
inputs = {
  kubernetes_version = "1.35"
  enable_irsa        = true

  eks_managed_node_groups = {
    group = {
      instance_types = ["t4g.small"]
      ami_type       = "AL2023_ARM_64_STANDARD"
      desired_size   = 4
      max_size       = 5
      min_size       = 1
    }
  }

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }
}
```

## Custom ArgoCD Module

```hcl
# terraform/modules/argocd/main.tf
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.17"
  namespace  = "argocd"

  values = var.helm_values
}
```

The module uses the EKS cluster endpoint with `aws eks get-token` for authentication — no static kubeconfig required.

![Terraform Module Graph]
