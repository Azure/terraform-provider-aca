# ---------------------------------------------------------------------------
# Required arguments – mirror azurerm_container_app 1:1
# ---------------------------------------------------------------------------

variable "name" {
  description = "The name of the Container App."
  type        = string
}

variable "location" {
  description = "The Azure region where the Container App should exist. Required for Express apps created through AzAPI."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the Container App."
  type        = string
}

variable "environment_mode" {
  description = "Mode of the target Container Apps environment."
  type        = string
  default     = "WorkloadProfiles"

  validation {
    condition     = contains(["WorkloadProfiles", "ConsumptionOnly", "Express"], var.environment_mode)
    error_message = "environment_mode must be one of: WorkloadProfiles, ConsumptionOnly, Express."
  }
}

variable "express_api_version" {
  description = "API version used to create Express Container Apps through AzAPI."
  type        = string
  default     = "2026-03-02-preview"
}

variable "container_app_environment_id" {
  description = "The ID of the Container App Environment to host this Container App."
  type        = string
}

variable "revision_mode" {
  description = "The revisions operational mode for the Container App. Possible values are `Single` and `Multiple`."
  type        = string

  validation {
    condition     = contains(["Single", "Multiple"], var.revision_mode)
    error_message = "revision_mode must be \"Single\" or \"Multiple\"."
  }
}

variable "template" {
  description = <<-EOT
    Container template configuration.
    Expected keys: containers (list), init_containers (optional list),
    volumes (optional list), min_replicas, max_replicas, revision_suffix (optional).
  EOT
  type = object({
    containers = list(object({
      name              = string
      image             = string
      cpu               = number
      memory            = string
      command           = optional(list(string))
      args              = optional(list(string))
      ephemeral_storage = optional(string)
      env = optional(list(object({
        name        = string
        value       = optional(string)
        secret_name = optional(string)
      })), [])
      volume_mounts = optional(list(object({
        name = string
        path = string
      })), [])
      liveness_probe  = optional(any)
      readiness_probe = optional(any)
      startup_probe   = optional(any)
    }))
    init_containers = optional(list(object({
      name   = string
      image  = string
      cpu    = optional(number)
      memory = optional(string)
      env = optional(list(object({
        name        = string
        value       = optional(string)
        secret_name = optional(string)
      })), [])
      volume_mounts = optional(list(object({
        name = string
        path = string
      })), [])
    })), [])
    volumes = optional(list(object({
      name         = string
      storage_type = optional(string)
      storage_name = optional(string)
    })), [])
    min_replicas    = optional(number)
    max_replicas    = optional(number)
    revision_suffix = optional(string)
    http_scale_rules = optional(list(object({
      name                = string
      concurrent_requests = number
    })), [])
    custom_scale_rules = optional(list(object({
      name             = string
      custom_rule_type = string
      metadata         = map(string)
      identity_id      = optional(string)
    })), [])
  })
}

# ---------------------------------------------------------------------------
# Optional arguments – mirror azurerm_container_app 1:1
# ---------------------------------------------------------------------------

variable "workload_profile_name" {
  description = "The name of the workload profile to pin this Container App to."
  type        = string
  default     = null
}

variable "tags" {
  description = "A mapping of tags to assign to the Container App."
  type        = map(string)
  default     = {}
}

variable "ingress" {
  description = "Ingress configuration block."
  type = object({
    target_port                = number
    external_enabled           = optional(bool, false)
    transport                  = optional(string, "auto")
    exposed_port               = optional(number)
    allow_insecure_connections = optional(bool, false)
    cors = optional(object({
      allow_credentials_enabled = optional(bool, false)
      allowed_headers           = optional(list(string))
      allowed_methods           = optional(list(string))
      allowed_origins           = list(string)
      exposed_headers           = optional(list(string))
      max_age_in_seconds        = optional(number)
    }))
    ip_security_restrictions = optional(list(object({
      action           = string
      description      = optional(string)
      ip_address_range = string
      name             = string
    })), [])
    traffic_weight = optional(list(object({
      percentage      = number
      label           = optional(string)
      latest_revision = optional(bool)
      revision_suffix = optional(string)
    })), [])
  })
  default = null
}

variable "outbound_vnet_subnet_id" {
  description = "Optional app-level outbound subnet for an Express app. It is immutable and mutually exclusive with environment-level VNet integration."
  type        = string
  default     = null
}

variable "environment_infrastructure_subnet_id" {
  description = "Environment-level subnet ID used only to validate Express app-level outbound VNet exclusivity."
  type        = string
  default     = null
}

variable "dapr" {
  description = "Dapr sidecar configuration block."
  type = object({
    app_id       = string
    app_port     = optional(number)
    app_protocol = optional(string)
  })
  default = null
}

variable "identity" {
  description = "Managed identity block."
  type = object({
    type         = string
    identity_ids = optional(list(string))
  })
  default = null
}

variable "registry" {
  description = "Container registry authentication blocks."
  type        = list(any)
  default     = []
}

variable "secret" {
  description = "Secret blocks for the Container App."
  type        = list(any)
  default     = []
}

# ---------------------------------------------------------------------------
# Feature flags & overrides – AzAPI overlay controls
# ---------------------------------------------------------------------------

variable "feature_flags" {
  description = "Toggle preview features backed by AzAPI overlay resources."
  type = object({
    advanced_ingress = optional(bool, false)
    kind_functionapp = optional(bool, false)
    dapr_app_health  = optional(bool, false)
    sticky_sessions  = optional(bool, false)
  })
  default = {}
}

variable "sticky_sessions_affinity" {
  description = "Sticky session affinity type (requires `feature_flags.sticky_sessions = true`). Possible values: `sticky`, `none`."
  type        = string
  default     = "sticky"
}

variable "provider_overrides" {
  description = "Override the default provider used for a feature flag (e.g. `{ advanced_ingress = \"azurerm\" }` to skip AzAPI)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Preview feature inputs – consumed only when the matching flag is true
# ---------------------------------------------------------------------------

variable "additional_port_mappings" {
  description = "Additional port mappings for advanced ingress (requires `feature_flags.advanced_ingress = true`)."
  type = list(object({
    external     = bool
    target_port  = number
    exposed_port = number
  }))
  default = []
}
