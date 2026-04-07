output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "web_app_url" {
  description = "FQDN of the web app's latest revision."
  value       = module.aca.container_apps["web"].latest_revision_fqdn
}

output "web_app_id" {
  description = "Resource ID of the web app."
  value       = module.aca.container_apps["web"].id
}

output "web_app_latest_revision" {
  description = "Name of the latest revision."
  value       = module.aca.container_apps["web"].latest_revision_name
}
