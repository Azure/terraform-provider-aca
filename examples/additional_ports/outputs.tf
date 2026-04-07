output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.aca.environment_default_domain
}

output "api_gateway_url" {
  description = "FQDN of the API gateway's latest revision (HTTP on port 80)."
  value       = module.aca.container_apps["api-gateway"].latest_revision_fqdn
}

output "api_gateway_id" {
  description = "Resource ID of the API gateway container app."
  value       = module.aca.container_apps["api-gateway"].id
}
