output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace."
  value       = local.log_analytics_workspace_id
}

output "log_analytics_workspace_primary_shared_key" {
  description = "Primary shared key of the Log Analytics workspace."
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].primary_shared_key : null
  sensitive   = true
}

output "application_insights_id" {
  description = "ID of the Application Insights instance."
  value       = var.create_application_insights ? azurerm_application_insights.this[0].id : null
}

output "application_insights_connection_string" {
  description = "Connection string of the Application Insights instance."
  value       = var.create_application_insights ? azurerm_application_insights.this[0].connection_string : null
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key of the Application Insights instance."
  value       = var.create_application_insights ? azurerm_application_insights.this[0].instrumentation_key : null
  sensitive   = true
}
