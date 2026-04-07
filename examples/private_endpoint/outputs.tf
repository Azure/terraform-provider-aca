output "environment_id" {
  description = "Container App Environment ID."
  value       = module.environment.id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.environment.default_domain
}

output "private_endpoint_ip" {
  description = "Private IP address of the ACA environment private endpoint."
  value       = azurerm_private_endpoint.aca.private_service_connection[0].private_ip_address
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone for ACA."
  value       = azurerm_private_dns_zone.aca.name
}

output "app_name" {
  description = "Name of the container app."
  value       = module.container_app.name
}

output "app_fqdn" {
  description = "Internal FQDN of the container app (resolvable via private DNS)."
  value       = module.container_app.latest_revision_fqdn
}
