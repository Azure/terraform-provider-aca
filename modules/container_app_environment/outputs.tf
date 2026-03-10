output "id" {
  description = "The ID of the Container App Environment."
  value       = azurerm_container_app_environment.this.id
}

output "name" {
  description = "The name of the Container App Environment."
  value       = azurerm_container_app_environment.this.name
}

output "default_domain" {
  description = "The default publicly resolvable domain name of the Container App Environment."
  value       = azurerm_container_app_environment.this.default_domain
}

output "static_ip_address" {
  description = "The static IP address of the Container App Environment."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "docker_bridge_cidr" {
  description = "The network addressing in which the Container App Environment operates."
  value       = azurerm_container_app_environment.this.docker_bridge_cidr
}

output "platform_reserved_cidr" {
  description = "The IP range in CIDR notation that is reserved for environment infrastructure IP addresses."
  value       = azurerm_container_app_environment.this.platform_reserved_cidr
}

output "platform_reserved_dns_ip_address" {
  description = "The IP address from the IP range defined by platform_reserved_cidr that is reserved for the internal DNS server."
  value       = azurerm_container_app_environment.this.platform_reserved_dns_ip_address
}
