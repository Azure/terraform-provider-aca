output "environment_id" {
  description = "Container App Environment ID."
  value       = module.environment.id
}

output "environment_name" {
  description = "Container App Environment name."
  value       = module.environment.name
}

output "environment_default_domain" {
  description = "Default domain of the environment."
  value       = module.environment.default_domain
}

output "java_app_id" {
  description = "Resource ID of the Java Spring Boot container app."
  value       = module.java_app.id
}

output "java_app_name" {
  description = "Name of the Java Spring Boot container app."
  value       = module.java_app.name
}

output "java_app_url" {
  description = "Public URL for the Java Spring Boot app."
  value       = try("https://${module.java_app.latest_revision_fqdn}", null)
}

output "eureka_id" {
  description = "Resource ID of the Spring Cloud Eureka component."
  value       = azapi_resource.eureka.id
}

output "config_server_id" {
  description = "Resource ID of the Spring Cloud Config Server component."
  value       = var.enable_config_server ? azapi_resource.config_server[0].id : null
}
