output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "web_app_url" {
  description = "Default FQDN of the web app."
  value       = try(module.aca.container_apps["web"].latest_revision_fqdn, null)
}

output "custom_domain_verification_id" {
  description = "Verification ID for DNS TXT record (asuid.<subdomain>)."
  value       = try(module.aca.container_apps["web"].custom_domain_verification_id, null)
}

output "custom_domain_bound" {
  description = "The custom domain that was bound (empty if none)."
  value       = var.custom_domain != "" ? var.custom_domain : null
}

output "app_urls" {
  description = "Map of app names to their latest revision FQDNs."
  value = {
    for k, v in module.aca.container_apps : k => v.latest_revision_fqdn
  }
}
