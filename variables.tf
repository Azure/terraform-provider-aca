variable "name" {
  description = "Base name for the ACA deployment. Used as prefix for child resources when individual names are not provided."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where ACA resources will be created."
  type        = string
}

variable "location" {
  description = "Azure region for the ACA deployment."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "networking" {
  description = <<-EOT
    Networking configuration for the ACA environment.
    Set to null to skip networking module (environment will use default networking).
    
    Attributes:
      create_vnet              - Create a new VNet (default: true)
      existing_vnet_id         - ID of existing VNet (when create_vnet = false)
      vnet_address_space       - Address space for new VNet
      aca_subnet_address_prefix - Subnet prefix (must be /23 or larger)
      create_nsg               - Create NSG for ACA subnet
      nsg_rules                - Custom NSG rules
  EOT
  type        = any
  default     = null
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

variable "observability" {
  description = <<-EOT
    Observability configuration for the ACA environment.
    Set to null to skip observability module.
    
    Attributes:
      create_log_analytics_workspace     - Create a new workspace (default: true)
      existing_log_analytics_workspace_id - ID of existing workspace
      log_analytics_retention_in_days     - Retention period
      create_application_insights         - Create App Insights
      diagnostic_settings                 - List of diagnostic setting configs
  EOT
  type        = any
  default     = null
}

# ---------------------------------------------------------------------------
# Container App Environment
# ---------------------------------------------------------------------------

variable "environment" {
  description = <<-EOT
    Container App Environment configuration. Mirrors azurerm_container_app_environment arguments.
    
    Required attributes:
      (none beyond root-level name, resource_group_name, location)
    
    Optional attributes:
      internal_load_balancer_enabled - Enable internal load balancer
      zone_redundancy_enabled       - Enable zone redundancy
      mutual_tls_enabled            - Enable mutual TLS
      workload_profile              - List of workload profile configs
      ingress_configuration         - Premium Ingress (dedicated ingress workload profile)
      infrastructure_resource_group_name - Custom infra RG name
      feature_flags                 - Preview feature flags (premium_ingress, peer_authentication)
      provider_overrides            - Provider routing overrides
  EOT
  type        = any
  default     = {}
}

# ---------------------------------------------------------------------------
# Container Apps
# ---------------------------------------------------------------------------

variable "container_apps" {
  description = <<-EOT
    Map of Container App configurations. Each key is the app identifier.
    Values mirror azurerm_container_app arguments.
    
    Required attributes per app:
      revision_mode - "Single" or "Multiple"
      template      - Container template configuration
    
    Optional attributes per app:
      name                  - Override app name (defaults to key)
      ingress               - Ingress configuration
      dapr                  - Dapr sidecar configuration
      identity              - Managed identity configuration
      registry              - Container registry auth
      secret                - Secret definitions
      workload_profile_name - Workload profile to use
      feature_flags         - Preview feature flags
      provider_overrides    - Provider routing overrides
  EOT
  type        = any
  default     = {}
}

# ---------------------------------------------------------------------------
# Container App Jobs
# ---------------------------------------------------------------------------

variable "jobs" {
  description = <<-EOT
    Map of Container App Job configurations. Each key is the job identifier.
    Values mirror azurerm_container_app_job arguments.
    
    Required attributes per job:
      replica_timeout_in_seconds - Timeout for job replicas
      template                   - Job template configuration
    
    Optional attributes per job:
      name                    - Override job name (defaults to key)
      replica_retry_limit     - Retry limit for failed replicas
      workload_profile_name   - Workload profile to use
      schedule_trigger_config - Schedule trigger configuration
      event_trigger_config    - Event trigger configuration
      manual_trigger_config   - Manual trigger configuration
      registry                - Container registry auth
      secret                  - Secret definitions
      identity                - Managed identity configuration
      feature_flags           - Preview feature flags
      provider_overrides      - Provider routing overrides
  EOT
  type        = any
  default     = {}
}
