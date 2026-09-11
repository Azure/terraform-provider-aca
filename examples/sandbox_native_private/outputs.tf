output "sandbox_group_id" {
  description = "ARM ID of the Sandbox Group."
  value       = module.sandbox_group.id
}

output "registry_login_server" {
  description = "ACR login server containing the imported image."
  value       = azurerm_container_registry.this.login_server
}

output "registry_token_name" {
  description = "Read-only ACR token name used for the disk import."
  value       = azurerm_container_registry_token.sandbox_pull.name
}

output "disk_image_id" {
  description = "Service-generated private disk image ID."
  value       = aca_sandbox_disk_image.azurelinux.id
}

output "disk_image_status" {
  description = "Current private disk image status."
  value       = aca_sandbox_disk_image.azurelinux.status
}

output "disk_image_resource_url" {
  description = "Canonical disk image data-plane URL used for import."
  value       = aca_sandbox_disk_image.azurelinux.resource_url
}

output "sandbox_id" {
  description = "Service-generated Sandbox ID."
  value       = aca_sandbox.azurelinux.id
}

output "sandbox_state" {
  description = "Current Sandbox operational state."
  value       = aca_sandbox.azurelinux.state
}

output "sandbox_resource_url" {
  description = "Canonical Sandbox data-plane URL used for import."
  value       = aca_sandbox.azurelinux.resource_url
}
