output "id" {
  description = "The ID of the Container App."
  value       = azurerm_container_app.this.id
}

output "name" {
  description = "The name of the Container App."
  value       = azurerm_container_app.this.name
}

output "latest_revision_name" {
  description = "The name of the latest revision of the Container App."
  value       = azurerm_container_app.this.latest_revision_name
}

output "latest_revision_fqdn" {
  description = "The FQDN of the latest revision of the Container App."
  value       = azurerm_container_app.this.latest_revision_fqdn
}

output "outbound_ip_addresses" {
  description = "A list of the public IP addresses of the Container App."
  value       = azurerm_container_app.this.outbound_ip_addresses
}

output "custom_domain_verification_id" {
  description = "The custom domain verification ID for the Container App."
  value       = azurerm_container_app.this.custom_domain_verification_id
}
