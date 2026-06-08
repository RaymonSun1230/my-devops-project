output "hosted_zone_id" {
  description = "The Route53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone (configure at registrar)"
  value       = aws_route53_zone.primary.name_servers
}

output "health_check_primary_id" {
  description = "Health check ID for primary region"
  value       = aws_route53_health_check.primary.id
}

output "health_check_secondary_id" {
  description = "Health check ID for secondary region"
  value       = aws_route53_health_check.secondary.id
}

output "frontend_record_fqdn" {
  description = "FQDN of the frontend failover record"
  value       = aws_route53_record.frontend.fqdn
}
