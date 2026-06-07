output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.namespace
}

output "argocd_server_endpoint" {
  description = "ArgoCD server service name (use with port-forward: kubectl port-forward svc/argocd-server -n <ns> 8080:443)"
  value       = "argocd-server.${var.namespace}.svc"
}

output "helm_release_status" {
  description = "Status of the argocd Helm release"
  value       = helm_release.argocd.status
}

output "get_admin_password_command" {
  description = "Shell command to retrieve the initial admin password"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
