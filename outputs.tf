# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the VNet created for ACA (null if networking module was skipped)."
  value       = try(module.networking[0].vnet_id, null)
}

output "subnet_id" {
  description = "ID of the ACA subnet (null if networking module was skipped)."
  value       = try(module.networking[0].subnet_id, null)
}

output "nsg_id" {
  description = "ID of the NSG for the ACA subnet (null if not created)."
  value       = try(module.networking[0].nsg_id, null)
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace (null if observability module was skipped)."
  value       = try(module.observability[0].log_analytics_workspace_id, null)
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

output "environment_id" {
  description = "ID of the Container App Environment."
  value       = module.environment.id
}

output "environment_name" {
  description = "Name of the Container App Environment."
  value       = module.environment.name
}

output "environment_default_domain" {
  description = "Default domain of the Container App Environment."
  value       = module.environment.default_domain
}

output "environment_static_ip_address" {
  description = "Static IP address of the Container App Environment."
  value       = module.environment.static_ip_address
}

output "environment_mode" {
  description = "Resolved Container App Environment mode."
  value       = module.environment.environment_mode
}

# ---------------------------------------------------------------------------
# Container Apps
# ---------------------------------------------------------------------------

output "container_apps" {
  description = "Map of Container App outputs keyed by app identifier."
  value = {
    for k, v in module.container_app : k => {
      id                    = v.id
      name                  = v.name
      latest_revision_name  = v.latest_revision_name
      latest_revision_fqdn  = v.latest_revision_fqdn
      outbound_ip_addresses = v.outbound_ip_addresses
    }
  }
}

# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

output "jobs" {
  description = "Map of Container App Job outputs keyed by job identifier."
  value = {
    for k, v in module.job : k => {
      id   = v.id
      name = v.name
    }
  }
}

# ---------------------------------------------------------------------------
# Sandbox Groups
# ---------------------------------------------------------------------------

output "sandbox_groups" {
  description = "Map of Sandbox Group outputs keyed by group identifier."
  value = {
    for k, v in module.sandbox_group : k => {
      id                                      = v.id
      name                                    = v.name
      location                                = v.location
      management_endpoint                     = v.management_endpoint
      default_domain                          = v.default_domain
      provisioning_state                      = v.provisioning_state
      principal_id                            = v.principal_id
      vnet_connection_ids                     = v.vnet_connection_ids
      api_profile                             = v.api_profile
      api_version                             = v.api_version
      data_plane_operator_role_assignment_ids = v.data_plane_operator_role_assignment_ids
      acr_pull_role_assignment_ids            = v.acr_pull_role_assignment_ids
      management_lock_id                      = v.management_lock_id
    }
  }
}
