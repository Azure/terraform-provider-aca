output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain for the environment."
  value       = module.aca.environment_default_domain
}

output "api_name" {
  description = "Name of the API container app."
  value       = try(module.aca.container_apps["api"].name, null)
}

output "vnet_id" {
  description = "VNet ID for the ACA environment."
  value       = module.aca.vnet_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the system-assigned managed identity for the API container app."
  # Requires the root module outputs.tf to expose container app identity attributes.
  value = try(module.aca.container_apps["api"].identity[0].principal_id, null)
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key."
  # Requires the root module outputs.tf to expose the observability module instrumentation key.
  value     = try(module.aca.application_insights_instrumentation_key, null)
  sensitive = true
}
