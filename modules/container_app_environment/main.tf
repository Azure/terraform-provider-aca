resource "azurerm_container_app_environment" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  log_analytics_workspace_id                  = var.log_analytics_workspace_id
  dapr_application_insights_connection_string = var.dapr_application_insights_connection_string
  infrastructure_resource_group_name          = var.infrastructure_resource_group_name
  infrastructure_subnet_id                    = var.infrastructure_subnet_id
  internal_load_balancer_enabled              = var.infrastructure_subnet_id != null ? var.internal_load_balancer_enabled : null
  zone_redundancy_enabled                     = var.infrastructure_subnet_id != null ? var.zone_redundancy_enabled : null
  mutual_tls_enabled                          = var.mutual_tls_enabled

  dynamic "workload_profile" {
    for_each = var.workload_profile
    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]

    precondition {
      condition     = !(var.internal_load_balancer_enabled || var.zone_redundancy_enabled) || var.infrastructure_subnet_id != null
      error_message = "infrastructure_subnet_id must be provided when internal_load_balancer_enabled or zone_redundancy_enabled is true. These features require VNet integration."
    }
  }
}
