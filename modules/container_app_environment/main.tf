locals {
  # Merge the dedicated ingress workload profile into the user-defined list
  ingress_workload_profile = var.ingress_configuration != null && var.feature_flags.premium_ingress ? [{
    name                  = var.ingress_configuration.workload_profile_name
    workload_profile_type = var.ingress_configuration.workload_profile_type
    minimum_count         = var.ingress_configuration.minimum_node_count
    maximum_count         = var.ingress_configuration.maximum_node_count
  }] : []

  workload_profiles = concat(var.workload_profile, local.ingress_workload_profile)
}

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
    for_each = local.workload_profiles
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

    precondition {
      condition     = var.ingress_configuration == null || !var.feature_flags.premium_ingress || !contains([for wp in var.workload_profile : wp.name], var.ingress_configuration.workload_profile_name)
      error_message = "ingress_configuration.workload_profile_name conflicts with a user-defined workload_profile. The dedicated ingress profile is auto-managed and must not be duplicated."
    }
  }
}
