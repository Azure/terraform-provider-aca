output "id" {
  description = "The ID of the Container App."
  value       = local.app_id
}

output "name" {
  description = "The name of the Container App."
  value       = var.name
}

output "latest_revision_name" {
  description = "The name of the latest revision of the Container App."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.latestRevisionName, null) : azurerm_container_app.this[0].latest_revision_name
}

output "latest_revision_fqdn" {
  description = "The FQDN of the latest revision of the Container App."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.latestRevisionFqdn, null) : azurerm_container_app.this[0].latest_revision_fqdn
}

output "outbound_ip_addresses" {
  description = "A list of the public IP addresses of the Container App."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.outboundIpAddresses, []) : azurerm_container_app.this[0].outbound_ip_addresses
}

output "custom_domain_verification_id" {
  description = "The custom domain verification ID for the Container App."
  value       = local.is_express ? try(azapi_resource.express[0].output.properties.customDomainVerificationId, null) : azurerm_container_app.this[0].custom_domain_verification_id
  sensitive   = true
}
