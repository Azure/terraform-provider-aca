output "id" {
  description = "ID of the Container App Job."
  value       = azurerm_container_app_job.this.id
}

output "name" {
  description = "Name of the Container App Job."
  value       = azurerm_container_app_job.this.name
}

output "outbound_ip_addresses" {
  description = "Outbound IP addresses of the Container App Job."
  value       = try(azurerm_container_app_job.this.outbound_ip_addresses, [])
}
