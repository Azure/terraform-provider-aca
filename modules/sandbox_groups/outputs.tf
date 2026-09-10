output "id" {
  description = "Full ARM resource ID of the sandbox group."
  value       = azapi_resource.this.id
}

output "name" {
  description = "Name of the sandbox group."
  value       = azapi_resource.this.name
}

output "location" {
  description = "Azure region of the sandbox group."
  value       = azapi_resource.this.location
}

output "management_endpoint" {
  description = "ADC data-plane endpoint (`https://management.{region}.azuredevcompute.io`). Use this to drive individual sandbox lifecycle via SDK/CLI/REST — sandboxes themselves are NOT ARM resources."
  value       = try(azapi_resource.this.output.properties.managementEndpoint, null)
}

output "default_domain" {
  description = "Default domain of the linked Container Apps environment when returned by the selected API contract."
  value       = try(azapi_resource.this.output.properties.defaultDomain, null)
}

output "provisioning_state" {
  description = "Last reported ARM provisioning state."
  value       = try(azapi_resource.this.output.properties.provisioningState, null)
}

output "principal_id" {
  description = "Principal ID of the system-assigned managed identity (null when not enabled)."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}

output "tenant_id" {
  description = "Tenant ID of the system-assigned managed identity (null when not enabled)."
  value       = try(azapi_resource.this.output.identity.tenantId, null)
}

output "vnet_connection_ids" {
  description = "Map of vnet connection name to ARM resource ID."
  value       = { for k, v in azapi_resource.vnet_connection : k => v.id }
}

output "api_profile" {
  description = "Selected Sandbox Group API profile."
  value       = var.api_profile
}

output "api_version" {
  description = "Resolved Sandbox Group API version."
  value       = local.api_version
}

output "data_plane_operator_role_assignment_ids" {
  description = "Map of SandboxGroup Data Owner role assignment IDs."
  value       = { for k, v in azurerm_role_assignment.data_plane_operator : k => v.id }
}

output "acr_pull_role_assignment_ids" {
  description = "Map of AcrPull role assignment IDs."
  value       = { for k, v in azurerm_role_assignment.acr_pull : k => v.id }
}

output "management_lock_id" {
  description = "ID of the optional CanNotDelete management lock."
  value       = try(azurerm_management_lock.this[0].id, null)
}
