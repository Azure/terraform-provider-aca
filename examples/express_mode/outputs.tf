output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_mode" {
  description = "Resolved environment mode."
  value       = module.aca.environment_mode
}

output "environment_default_domain" {
  description = "Default domain of the Express environment."
  value       = module.aca.environment_default_domain
}

output "app_id" {
  description = "Express Container App resource ID."
  value       = module.aca.container_apps["hello"].id
}

output "app_url" {
  description = "Public URL of the Express sample app."
  value       = "https://${module.aca.container_apps["hello"].latest_revision_fqdn}"
}
