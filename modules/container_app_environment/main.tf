locals {
  environment_mode = var.feature_flags.express_mode ? "Express" : coalesce(
    var.environment_mode,
    length(var.workload_profile) > 0 ? "WorkloadProfiles" : "ConsumptionOnly"
  )
  is_express = local.environment_mode == "Express"

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
  count = local.is_express ? 0 : 1

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

    precondition {
      condition     = !var.feature_flags.express_mode || var.environment_mode == null || var.environment_mode == "Express"
      error_message = "feature_flags.express_mode = true conflicts with a non-Express environment_mode."
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azapi_resource" "express" {
  count = local.is_express ? 1 : 0

  type      = "Microsoft.App/managedEnvironments@${var.express_api_version}"
  name      = var.name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  schema_validation_enabled = false
  ignore_null_property      = true
  response_export_values = [
    "properties.defaultDomain",
    "properties.environmentMode",
    "properties.provisioningState",
    "properties.staticIp",
  ]

  body = {
    properties = merge(
      {
        environmentMode = "Express"
      },
      var.infrastructure_subnet_id != null ? {
        vnetConfiguration = {
          infrastructureSubnetId = var.infrastructure_subnet_id
        }
      } : {},
      var.log_analytics_workspace_customer_id != null && var.log_analytics_workspace_shared_key != null ? {
        appLogsConfiguration = {
          destination = "log-analytics"
          logAnalyticsConfiguration = {
            customerId = var.log_analytics_workspace_customer_id
            sharedKey  = var.log_analytics_workspace_shared_key
          }
        }
      } : {}
    )
  }

  lifecycle {
    ignore_changes = [tags]

    precondition {
      condition     = !var.feature_flags.express_mode || var.environment_mode == null || var.environment_mode == "Express"
      error_message = "feature_flags.express_mode = true conflicts with a non-Express environment_mode."
    }

    precondition {
      condition     = (var.log_analytics_workspace_customer_id == null) == (var.log_analytics_workspace_shared_key == null)
      error_message = "Express Log Analytics configuration requires both log_analytics_workspace_customer_id and log_analytics_workspace_shared_key."
    }

    precondition {
      condition     = var.log_analytics_workspace_id == null || var.log_analytics_workspace_customer_id != null
      error_message = "Express environments cannot use log_analytics_workspace_id alone; provide the workspace customer ID and shared key."
    }

    precondition {
      condition     = var.infrastructure_resource_group_name == null && !var.internal_load_balancer_enabled && !var.zone_redundancy_enabled && !var.mutual_tls_enabled && length(var.workload_profile) == 0 && var.ingress_configuration == null && !var.feature_flags.peer_authentication && !var.feature_flags.premium_ingress
      error_message = "Express environments do not support infrastructure_resource_group_name, internal load balancers, zone redundancy, mutual TLS, workload profiles, peer authentication, or premium ingress."
    }
  }
}

locals {
  environment_id = local.is_express ? azapi_resource.express[0].id : azurerm_container_app_environment.this[0].id
}
