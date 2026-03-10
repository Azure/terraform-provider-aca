output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "api_url" {
  description = "Public URL for the API app."
  value       = try("https://${module.aca.container_apps["api"].latest_revision_fqdn}", null)
}

output "frontend_url" {
  description = "Public URL for the frontend app."
  value       = try("https://${module.aca.container_apps["frontend"].latest_revision_fqdn}", null)
}

output "api_id" {
  description = "Resource ID of the API container app."
  value       = module.aca.container_apps["api"].id
}
