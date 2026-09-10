output "sandbox_group_id" {
  description = "ARM ID of the Sandbox Group."
  value       = module.sandbox_group.id
}

output "sandbox_group_management_endpoint" {
  description = "Regional Sandbox data-plane endpoint."
  value       = module.sandbox_group.management_endpoint
}

output "public_disk_image_status" {
  description = "Status of the public Ubuntu disk image."
  value       = data.aca_sandbox_public_disk_image.ubuntu.status
}

output "sandbox_id" {
  description = "Service-generated Sandbox ID."
  value       = aca_sandbox.ubuntu.id
}

output "sandbox_state" {
  description = "Current Sandbox operational state."
  value       = aca_sandbox.ubuntu.state
}

output "sandbox_resource_url" {
  description = "Canonical data-plane resource URL used for import."
  value       = aca_sandbox.ubuntu.resource_url
}
