output "id" {
  description = "The ID of the Container App Environment."
  value       = local.environment_id
}

output "name" {
  description = "The name of the Container App Environment."
  value       = var.name
}

output "default_domain" {
  description = "The default publicly resolvable domain name of the Container App Environment."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.defaultDomain, null) : azurerm_container_app_environment.this[0].default_domain
}

output "static_ip_address" {
  description = "The static IP address of the Container App Environment."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.staticIp, null) : azurerm_container_app_environment.this[0].static_ip_address
}

output "docker_bridge_cidr" {
  description = "The network addressing in which the Container App Environment operates."
  value       = local.is_express ? null : azurerm_container_app_environment.this[0].docker_bridge_cidr
}

output "platform_reserved_cidr" {
  description = "The IP range in CIDR notation that is reserved for environment infrastructure IP addresses."
  value       = local.is_express ? null : azurerm_container_app_environment.this[0].platform_reserved_cidr
}

output "platform_reserved_dns_ip_address" {
  description = "The IP address from the IP range defined by platform_reserved_cidr that is reserved for the internal DNS server."
  value       = local.is_express ? null : azurerm_container_app_environment.this[0].platform_reserved_dns_ip_address
}

output "environment_mode" {
  description = "The resolved managed environment mode."
  value       = local.environment_mode
}
