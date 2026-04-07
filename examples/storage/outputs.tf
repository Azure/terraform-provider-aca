output "environment_id" {
  description = "Container App Environment ID."
  value       = module.environment.id
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "data_share_name" {
  description = "Data file share name."
  value       = azurerm_storage_share.data.name
}

output "app_name" {
  description = "Name of the container app with mounted storage."
  value       = module.container_app.name
}
