output "environment_id" {
  description = "Container App Environment ID."
  value       = module.environment.id
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.environment.default_domain
}

output "web_app_id" {
  description = "Resource ID of the web app."
  value       = module.web_app.id
}

output "web_app_url" {
  description = "FQDN of the web app's latest revision."
  value       = module.web_app.latest_revision_fqdn
}

output "worker_app_id" {
  description = "Resource ID of the worker app."
  value       = module.worker_app.id
}

output "worker_app_name" {
  description = "Name of the worker app."
  value       = module.worker_app.name
}
