output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "web_url" {
  description = "Public URL for the web app."
  value       = try("https://${module.aca.container_apps["web"].latest_revision_fqdn}", null)
}

output "web_id" {
  description = "Resource ID of the web container app."
  value       = module.aca.container_apps["web"].id
}

output "web_name" {
  description = "Name of the web container app."
  value       = module.aca.container_apps["web"].name
}
