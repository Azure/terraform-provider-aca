output "sandbox_group_id" {
  description = "ARM resource ID of the sandbox group."
  value       = module.aca.sandbox_groups["agents"].id
}

output "sandbox_group_name" {
  description = "Name of the sandbox group."
  value       = module.aca.sandbox_groups["agents"].name
}

output "sandbox_group_management_endpoint" {
  description = <<-EOT
    ADC data-plane endpoint for the group. Use this as the base URL when
    creating, listing, or destroying individual sandboxes from the ACA CLI
    (`aca sandbox ...`) or SDK. Sandboxes are NOT ARM resources and cannot
    be managed by Terraform.
  EOT
  value       = module.aca.sandbox_groups["agents"].management_endpoint
}

output "sandbox_group_principal_id" {
  description = "Principal ID of the system-assigned managed identity attached to the group."
  value       = module.aca.sandbox_groups["agents"].principal_id
}

output "sandbox_group_vnet_connection_ids" {
  description = "Map of vnet connection name → ARM resource ID for the group."
  value       = module.aca.sandbox_groups["agents"].vnet_connection_ids
}

output "sandbox_subnet_id" {
  description = "ID of the delegated subnet bound to the sandbox group."
  value       = azurerm_subnet.sandbox.id
}
