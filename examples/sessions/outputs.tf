output "environment_id" {
  description = "Container App Environment ID."
  value       = module.aca.environment_id
}

output "session_pool_id" {
  description = "Dynamic session pool ID."
  value       = azapi_resource.session_pool.id
}

output "session_pool_name" {
  description = "Dynamic session pool name."
  value       = azapi_resource.session_pool.name
}

output "session_pool_management_endpoint" {
  description = "Pool management endpoint — set this as var.session_pool_endpoint and re-apply."
  value       = try(jsondecode(azapi_resource.session_pool.output).properties.poolManagementEndpoint, null)
}

output "client_app_name" {
  description = "Name of the session client container app."
  value       = try(module.aca.container_apps["session-client"].name, null)
}
