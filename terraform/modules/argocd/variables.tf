variable "cluster_name" {
  description = "Name of the EKS cluster to install ArgoCD on"
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster is running"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install ArgoCD into"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo-cd Helm chart (https://github.com/argoproj/argo-helm)"
  type        = string
  default     = "7.8.17"
}

variable "helm_values" {
  description = "Additional Helm values to pass to the argo-cd chart"
  type        = any
  default     = []
}
