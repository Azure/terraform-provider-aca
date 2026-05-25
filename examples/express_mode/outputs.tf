output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "environment_default_domain" {
  description = "Default domain of the Express environment."
  value       = module.aca.environment_default_domain
}

output "environment_mode" {
  description = "environmentMode of the managed environment as reported by the module."
  value       = module.aca.environment_id == null ? null : "Express"
}

output "api_app_id" {
  description = "ARM resource ID of the sample app."
  value       = azapi_resource.api.id
}

output "api_app_url" {
  description = "Public FQDN of the sample app on the Express environment."
  value       = try("https://${azapi_resource.api.output.properties.configuration.ingress.fqdn}", null)
}
