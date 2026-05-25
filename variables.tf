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
      feature_flags                 - Preview feature flags (premium_ingress, peer_authentication, express_mode)
      provider_overrides            - Provider routing overrides
      express_api_version           - Preview API version for the Express overlay (default 2025-10-02-preview)
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

# ---------------------------------------------------------------------------
# Sandbox Groups (ACA Sandboxes — early access)
# ---------------------------------------------------------------------------

variable "sandbox_groups" {
  description = <<-EOT
    Map of Microsoft.App/sandboxGroups (ACA Sandboxes) keyed by group identifier.
    Sandbox groups are a brand-new ARM resource type with no AzureRM coverage —
    the module manages them via AzAPI. Individual sandbox CRUD is data-plane only
    (management.{region}.azuredevcompute.io) and is out of scope for Terraform.

    Required attributes per group:
      (none beyond the key — sensible defaults are applied)

    Optional attributes per group:
      name                    - Override sandbox group name (defaults to "{var.name}-{key}")
      location                - Azure region (defaults to var.location)
      default_cpu             - Default vCPU per sandbox (e.g. "0.25", "1", "2")
      default_memory          - Default memory (e.g. "1Gi", "4Gi")
      default_disk            - Default ephemeral disk size (e.g. "20Gi")
      max_sandbox_count       - Concurrent sandbox cap
      default_timeout_seconds - Auto-teardown timeout
      network_config          - { public_network_access, subnet_id }
      identity                - { type, identity_ids }
      gateway_connections     - List of MCP server connections
      vnet_connections        - Map of child vnet connections keyed by name
      tags                    - Per-group tags merged on top of root tags
  EOT
  type = map(object({
    name                    = optional(string)
    location                = optional(string)
    default_cpu             = optional(string)
    default_memory          = optional(string)
    default_disk            = optional(string)
    max_sandbox_count       = optional(number)
    default_timeout_seconds = optional(number)
    network_config = optional(object({
      public_network_access = optional(string)
      subnet_id             = optional(string)
    }))
    identity = optional(object({
      type         = string
      identity_ids = optional(list(string), [])
    }))
    gateway_connections = optional(list(object({
      resource_id     = string
      mcp_runtime_url = optional(string)
      authentication = optional(object({
        type                 = string
        identity_resource_id = optional(string)
      }))
    })), [])
    vnet_connections = optional(map(object({
      subnet_id = string
    })), {})
    tags        = optional(map(string), {})
    api_version = optional(string)
  }))
  default = {}
}
