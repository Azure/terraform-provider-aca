output "sandbox_group_id" {
  description = "ARM ID of the rich-preview Sandbox Group."
  value       = module.sandbox_group.id
}

output "sandbox_group_principal_id" {
  description = "System-assigned identity used for ACR disk import."
  value       = module.sandbox_group.principal_id
}

output "immutable_image_reference" {
  description = "Digest-pinned interpreter image imported by the workload companion."
  value       = data.external.image.result.immutable_reference
}

output "sandbox_id" {
  description = "Data-plane Sandbox ID."
  value       = module.code_interpreter.sandbox_id
}

output "disk_id" {
  description = "Data-plane disk ID."
  value       = module.code_interpreter.disk_id
}

output "disk_name" {
  description = "Data-plane disk name."
  value       = module.code_interpreter.disk_name
}

output "port_urls" {
  description = "Named Sandbox port URLs."
  value       = module.code_interpreter.port_urls
}

output "primary_port_url" {
  description = "Primary Sandbox port URL."
  value       = module.code_interpreter.primary_port_url
}

output "mcp_url" {
  description = "Streamable HTTP MCP endpoint."
  value       = module.code_interpreter.mcp_url
}

output "health_url" {
  description = "Unauthenticated health endpoint."
  value       = module.code_interpreter.health_url
}

output "selector_labels" {
  description = "Effective Sandbox selector labels."
  value       = module.code_interpreter.selector_labels
}

output "config_fingerprint" {
  description = "Deterministic non-secret workload configuration fingerprint."
  value       = module.code_interpreter.config_fingerprint
}

output "mcp_auth_token" {
  description = "Bearer token required by the MCP endpoint."
  value       = random_password.mcp_auth_token.result
  sensitive   = true
}

output "preservation_notice" {
  description = "Workload companion destroy behavior."
  value       = module.code_interpreter.preservation_notice
}
