output "sandbox_id" {
  description = "Data-plane Sandbox ID."
  value       = data.external.workload.result.sandbox_id
}

output "disk_id" {
  description = "Data-plane disk ID imported from the immutable image."
  value       = data.external.workload.result.disk_id
}

output "disk_name" {
  description = "Data-plane disk name."
  value       = data.external.workload.result.disk_name
}

output "port_urls" {
  description = "Map of caller-supplied port names to Sandbox endpoint URLs."
  value       = jsondecode(data.external.workload.result.port_urls_json)
}

output "primary_port_url" {
  description = "Endpoint URL for primary_port_name."
  value       = data.external.workload.result.primary_port_url
}

output "mcp_url" {
  description = "MCP URL derived from the primary port and mcp_path."
  value       = data.external.workload.result.mcp_url
}

output "health_url" {
  description = "Health URL derived from the primary port and health_path."
  value       = data.external.workload.result.health_url
}

output "selector_labels" {
  description = "Effective deterministic selector labels, including aca_config_fingerprint."
  value       = jsondecode(data.external.workload.result.selector_labels_json)
}

output "config_fingerprint" {
  description = "Deterministic workload configuration fingerprint. Sensitive environment values are excluded."
  value       = data.external.workload.result.config_fingerprint
}

output "preservation_notice" {
  description = "Data-plane preservation behavior recorded in Terraform state."
  value       = local.preservation_notice
}
