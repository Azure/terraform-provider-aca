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

# ---------------------------------------------------------------------------
# Optional arguments – mirrors azurerm_container_app_environment 1:1
# ---------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace to link to this Container App Environment."
  type        = string
  default     = null
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
  })
  default = {}
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
