output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "app_urls" {
  description = "Map of app names to their latest revision FQDNs."
  value = {
    for k, v in module.aca.container_apps : k => v.latest_revision_fqdn
  }
}
