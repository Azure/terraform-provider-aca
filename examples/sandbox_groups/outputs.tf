output "sandbox_group_id" {
  description = "ARM resource ID of the Sandbox Group."
  value       = module.sandbox_group.id
}

output "sandbox_group_name" {
  description = "Sandbox Group name."
  value       = module.sandbox_group.name
}

output "sandbox_group_api_profile" {
  description = "Selected minimal stable-shaped or rich-preview profile."
  value       = module.sandbox_group.api_profile
}

output "sandbox_group_api_version" {
  description = "Resolved ARM API version."
  value       = module.sandbox_group.api_version
}

output "sandbox_group_management_endpoint" {
  description = "Preview-only regional data-plane endpoint when returned by the service."
  value       = module.sandbox_group.management_endpoint
}

output "sandbox_group_principal_id" {
  description = "Rich-preview system-assigned identity principal ID."
  value       = module.sandbox_group.principal_id
}

output "sandbox_group_vnet_connection_ids" {
  description = "Map of VNet connection resource IDs."
  value       = module.sandbox_group.vnet_connection_ids
}

output "sandbox_subnet_id" {
  description = "Delegated subnet ID."
  value       = azurerm_subnet.sandbox.id
}
