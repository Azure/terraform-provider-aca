# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"
  count  = var.networking != null ? 1 : 0

  name_prefix         = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  create_vnet               = try(var.networking.create_vnet, true)
  existing_vnet_id          = try(var.networking.existing_vnet_id, null)
  vnet_address_space        = try(var.networking.vnet_address_space, ["10.0.0.0/16"])
  aca_subnet_address_prefix = try(var.networking.aca_subnet_address_prefix, "10.0.0.0/23")
  create_nsg                = try(var.networking.create_nsg, true)
  nsg_rules                 = try(var.networking.nsg_rules, [])
  tags                      = var.tags
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

module "observability" {
  source = "./modules/observability"
  count  = var.observability != null ? 1 : 0

  name_prefix         = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  create_log_analytics_workspace      = try(var.observability.create_log_analytics_workspace, true)
  existing_log_analytics_workspace_id = try(var.observability.existing_log_analytics_workspace_id, null)
  log_analytics_sku                   = try(var.observability.log_analytics_sku, "PerGB2018")
  log_analytics_retention_in_days     = try(var.observability.log_analytics_retention_in_days, 30)
  create_application_insights         = try(var.observability.create_application_insights, false)
  application_insights_type           = try(var.observability.application_insights_type, "web")
  diagnostic_settings                 = try(var.observability.diagnostic_settings, [])
  tags                                = var.tags
}

# ---------------------------------------------------------------------------
# Container App Environment
# ---------------------------------------------------------------------------

module "environment" {
  source = "./modules/container_app_environment"

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  log_analytics_workspace_id                  = try(module.observability[0].log_analytics_workspace_id, try(var.environment.log_analytics_workspace_id, null))
  dapr_application_insights_connection_string = try(module.observability[0].application_insights_connection_string, try(var.environment.dapr_application_insights_connection_string, null))
  infrastructure_resource_group_name          = try(var.environment.infrastructure_resource_group_name, null)
  infrastructure_subnet_id                    = try(module.networking[0].subnet_id, try(var.environment.infrastructure_subnet_id, null))
  internal_load_balancer_enabled              = try(var.environment.internal_load_balancer_enabled, false)
  zone_redundancy_enabled                     = try(var.environment.zone_redundancy_enabled, false)
  mutual_tls_enabled                          = try(var.environment.mutual_tls_enabled, false)
  workload_profile                            = try(var.environment.workload_profile, [])
  ingress_configuration                       = try(var.environment.ingress_configuration, null)
  feature_flags                               = try(var.environment.feature_flags, {})
  provider_overrides                          = try(var.environment.provider_overrides, {})
  tags                                        = var.tags
}

# ---------------------------------------------------------------------------
# Container Apps
# ---------------------------------------------------------------------------

module "container_app" {
  source   = "./modules/container_app"
  for_each = var.container_apps

  name                         = try(each.value.name, "${var.name}-${each.key}")
  resource_group_name          = var.resource_group_name
  container_app_environment_id = module.environment.id
  revision_mode                = each.value.revision_mode
  template                     = each.value.template

  ingress               = try(each.value.ingress, null)
  dapr                  = try(each.value.dapr, null)
  identity              = try(each.value.identity, null)
  registry              = try(each.value.registry, [])
  secret                = try(each.value.secret, [])
  workload_profile_name = try(each.value.workload_profile_name, null)
  tags                  = merge(var.tags, try(each.value.tags, {}))

  feature_flags            = try(each.value.feature_flags, {})
  provider_overrides       = try(each.value.provider_overrides, {})
  additional_port_mappings = try(each.value.additional_port_mappings, [])
}

# ---------------------------------------------------------------------------
# Container App Jobs
# ---------------------------------------------------------------------------

module "job" {
  source   = "./modules/jobs"
  for_each = var.jobs

  name                         = try(each.value.name, "${var.name}-${each.key}")
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = module.environment.id
  replica_timeout_in_seconds   = each.value.replica_timeout_in_seconds
  template                     = each.value.template

  replica_retry_limit     = try(each.value.replica_retry_limit, 0)
  workload_profile_name   = try(each.value.workload_profile_name, null)
  schedule_trigger_config = try(each.value.schedule_trigger_config, null)
  event_trigger_config    = try(each.value.event_trigger_config, null)
  manual_trigger_config   = try(each.value.manual_trigger_config, null)
  registry                = try(each.value.registry, [])
  secret                  = try(each.value.secret, [])
  identity                = try(each.value.identity, null)
  tags                    = merge(var.tags, try(each.value.tags, {}))

  feature_flags      = try(each.value.feature_flags, {})
  provider_overrides = try(each.value.provider_overrides, {})
}
