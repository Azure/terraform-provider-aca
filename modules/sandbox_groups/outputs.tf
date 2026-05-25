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
