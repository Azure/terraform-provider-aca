output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain for the environment."
  value       = module.aca.environment_default_domain
}

output "frontend_url" {
  description = "Public URL for the frontend app."
  value       = try("https://${module.aca.container_apps["frontend"].latest_revision_fqdn}", null)
}

output "backend_api_name" {
  description = "Name of the backend API container app."
  value       = try(module.aca.container_apps["backend-api"].name, null)
}

output "worker_name" {
  description = "Name of the worker container app."
  value       = try(module.aca.container_apps["worker"].name, null)
}
