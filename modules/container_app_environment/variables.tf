# ---------------------------------------------------------------------------
# Required arguments
# ---------------------------------------------------------------------------

variable "name" {
  description = "The name of the Container App Environment."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the Container App Environment."
  type        = string
}

variable "location" {
  description = "The Azure region where the Container App Environment should exist."
  type        = string
}

variable "environment_mode" {
  description = "Container Apps environment mode. Set to null to infer WorkloadProfiles when profiles are configured and ConsumptionOnly otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.environment_mode == null || contains(["WorkloadProfiles", "ConsumptionOnly", "Express"], var.environment_mode)
    error_message = "environment_mode must be null or one of: WorkloadProfiles, ConsumptionOnly, Express."
  }
}

# ---------------------------------------------------------------------------
# Optional arguments – mirrors azurerm_container_app_environment 1:1
# ---------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace to link to this Container App Environment."
  type        = string
  default     = null
}

variable "log_analytics_workspace_customer_id" {
  description = "Log Analytics workspace customer ID. Required with log_analytics_workspace_shared_key to enable logs on an Express environment."
  type        = string
  default     = null
}

variable "log_analytics_workspace_shared_key" {
  description = "Log Analytics workspace shared key. Required with log_analytics_workspace_customer_id to enable logs on an Express environment."
  type        = string
  default     = null
  sensitive   = true
}

variable "dapr_application_insights_connection_string" {
  description = "Application Insights connection string used by Dapr to export service-to-service communication telemetry."
  type        = string
  default     = null
  sensitive   = true
}

variable "infrastructure_resource_group_name" {
  description = "The name of the platform-managed resource group created for the Managed Environment."
  type        = string
  default     = null
}

variable "infrastructure_subnet_id" {
  description = "The existing subnet to use for the Container App Environment."
  type        = string
  default     = null
}

variable "internal_load_balancer_enabled" {
  description = "Should the Container App Environment operate in internal load balancing mode?"
  type        = bool
  default     = false
}

variable "zone_redundancy_enabled" {
  description = "Should the Container App Environment be zone-redundant?"
  type        = bool
  default     = false
}

variable "mutual_tls_enabled" {
  description = "Should mutual TLS (mTLS) be enabled for the Container App Environment?"
  type        = bool
  default     = false
}

variable "workload_profile" {
  description = "List of workload profiles to configure for the Container App Environment."
  type = list(object({
    name                  = string
    workload_profile_type = string
    minimum_count         = number
    maximum_count         = number
  }))
  default = []
}

variable "tags" {
  description = "A mapping of tags to assign to the Container App Environment."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# AzAPI overlay – preview / experimental features
# ---------------------------------------------------------------------------

variable "feature_flags" {
  description = "Toggle preview features that are applied via AzAPI overlay resources."
  type = object({
    peer_authentication = optional(bool, false)
    premium_ingress     = optional(bool, false)
    express_mode        = optional(bool, false)
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Express mode
# ---------------------------------------------------------------------------

variable "express_api_version" {
  description = <<-EOT
    API version used to create Express managed environments through AzAPI.
    Override only for a documented compatibility requirement.
  EOT
  type        = string
  default     = "2026-03-02-preview"
}

# ---------------------------------------------------------------------------
# Premium Ingress configuration
# ---------------------------------------------------------------------------

variable "ingress_configuration" {
  description = <<-EOT
    Premium Ingress configuration (requires `feature_flags.premium_ingress = true`).
    Runs ingress proxies on a dedicated workload profile instead of shared infrastructure.

    Attributes:
      workload_profile_name            - Name of the dedicated ingress workload profile (default: "premium-ingress")
      workload_profile_type            - SKU: D4, D8, D16, or D32 (default: "D4")
      minimum_node_count               - Minimum ingress nodes, must be >= 2 (default: 2)
      maximum_node_count               - Maximum ingress nodes (default: 10)
      termination_grace_period_minutes - Grace period in minutes, 1-60 (null = backend default)
      request_idle_timeout             - Idle timeout in minutes, 4-30 (null = backend default)
      header_count_limit               - Max HTTP headers per request (null = backend default)
  EOT
  type = object({
    workload_profile_name            = optional(string, "premium-ingress")
    workload_profile_type            = optional(string, "D4")
    minimum_node_count               = optional(number, 2)
    maximum_node_count               = optional(number, 10)
    termination_grace_period_minutes = optional(number, null)
    request_idle_timeout             = optional(number, null)
    header_count_limit               = optional(number, null)
  })
  default = null

  validation {
    condition     = var.ingress_configuration == null || contains(["D4", "D8", "D16", "D32"], var.ingress_configuration.workload_profile_type)
    error_message = "workload_profile_type must be one of: D4, D8, D16, D32."
  }

  validation {
    condition     = var.ingress_configuration == null || var.ingress_configuration.minimum_node_count >= 2
    error_message = "minimum_node_count must be at least 2."
  }

  validation {
    condition     = var.ingress_configuration == null || var.ingress_configuration.maximum_node_count >= var.ingress_configuration.minimum_node_count
    error_message = "maximum_node_count must be greater than or equal to minimum_node_count."
  }

  validation {
    condition     = var.ingress_configuration == null || var.ingress_configuration.termination_grace_period_minutes == null || (var.ingress_configuration.termination_grace_period_minutes >= 1 && var.ingress_configuration.termination_grace_period_minutes <= 60)
    error_message = "termination_grace_period_minutes must be between 1 and 60."
  }

  validation {
    condition     = var.ingress_configuration == null || var.ingress_configuration.request_idle_timeout == null || (var.ingress_configuration.request_idle_timeout >= 4 && var.ingress_configuration.request_idle_timeout <= 30)
    error_message = "request_idle_timeout must be between 4 and 30."
  }
}

variable "provider_overrides" {
  description = <<-EOT
    Override the provider used for a given feature flag. By default each preview
    feature uses AzAPI. Set the key to "azurerm" to skip the AzAPI resource
    (useful once the feature graduates to GA in the AzureRM provider).
    Example: { peer_authentication = "azurerm" }
  EOT
  type        = map(string)
  default     = {}
}
