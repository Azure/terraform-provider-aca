variable "subscription_id" {
  description = "Azure subscription containing the Sandbox Group."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription GUID."
  }
}

variable "resource_group_name" {
  description = "Resource group containing the Sandbox Group."
  type        = string
}

variable "location" {
  description = "Azure region used by the Sandbox data-plane endpoint."
  type        = string
}

variable "sandbox_group_name" {
  description = "Sandbox Group name."
  type        = string
}

variable "sandbox_group_id" {
  description = "Full ARM resource ID of the Sandbox Group. Used in replacement detection and state documentation."
  type        = string
}

variable "image_reference" {
  description = "Immutable OCI image reference in registry/repository@sha256:<64 hex characters> form."
  type        = string

  validation {
    condition     = can(regex("^[^[:space:]]+@sha256:[0-9a-fA-F]{64}$", var.image_reference))
    error_message = "image_reference must be immutable and use registry/repository@sha256:<64 hex characters>."
  }
}

variable "disk_name" {
  description = "Optional data-plane disk name. A deterministic name derived from the image digest is used when null."
  type        = string
  default     = null

  validation {
    condition     = var.disk_name == null || length(trimspace(var.disk_name)) > 0
    error_message = "disk_name must be null or a non-empty string."
  }
}

variable "disk_import_identity" {
  description = "Identity used to import the image into a Sandbox disk: \"system\", a user-assigned identity resource ID, or null for an anonymously pullable image."
  type        = string
  default     = "system"
}

variable "allow_registry_token_fallback" {
  description = "Explicitly allow a short-lived ACR token fallback after an authentication-related managed-identity import failure."
  type        = bool
  default     = false
}

variable "registry_name" {
  description = "ACR resource name used only by the explicitly enabled registry-token fallback."
  type        = string
  default     = null
}

variable "selector_labels" {
  description = "Stable labels used to select an existing Sandbox. The module adds aca_config_fingerprint."
  type        = map(string)

  validation {
    condition     = length(var.selector_labels) > 0
    error_message = "selector_labels must contain at least one stable workload label."
  }
}

variable "resources" {
  description = "Sandbox resources using ACA manifest units, for example cpu=2000m and memory=4096Mi."
  type = object({
    cpu    = string
    memory = string
    disk   = optional(string)
  })
}

variable "entrypoint" {
  description = "Optional entrypoint array supported by the ACA Sandbox manifest."
  type        = list(string)
  default     = []
}

variable "command" {
  description = "Optional command plus arguments. This maps to the current ACA manifest `cmd` array; the schema has no separate args property."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Non-sensitive environment variables. Values are included in the configuration fingerprint."
  type        = map(string)
  default     = {}
}

variable "sensitive_environment" {
  description = "Sensitive environment variables passed through the provisioner process environment. Values are excluded from the configuration fingerprint."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "sensitive_environment_revision" {
  description = "Optional non-sensitive rotation identifier. Change it when sensitive environment values change so Terraform creates a new Sandbox."
  type        = string
  default     = ""
}

variable "lifecycle_policy" {
  description = "ACA Sandbox lifecycle policy. Auto-suspend is configurable; auto-delete must remain disabled to preserve data-plane resources."
  type = object({
    auto_suspend_enabled          = optional(bool, false)
    auto_suspend_interval_seconds = optional(number, 0)
    auto_suspend_mode             = optional(string, "Memory")
    auto_delete_enabled           = optional(bool, false)
    auto_delete_interval_seconds  = optional(number, 0)
  })
  default = {}

  validation {
    condition     = !var.lifecycle_policy.auto_delete_enabled && var.lifecycle_policy.auto_delete_interval_seconds == 0
    error_message = "Sandbox auto-delete must remain disabled. Data-plane resources are preserved unless an operator explicitly deletes them outside Terraform."
  }
}

variable "egress_policy" {
  description = "ACA Sandbox egress policy. rules is passed through to the current manifest schema."
  type = object({
    default_action = optional(string, "Deny")
    host_rules = optional(list(object({
      pattern = string
      action  = string
    })), [])
    rules = optional(any, [])
  })
  default = {}

  validation {
    condition     = contains(["Allow", "Deny"], var.egress_policy.default_action)
    error_message = "egress_policy.default_action must be Allow or Deny."
  }

  validation {
    condition = alltrue([
      for rule in var.egress_policy.host_rules : contains(["Allow", "Deny"], rule.action)
    ])
    error_message = "Every egress host rule action must be Allow or Deny."
  }
}

variable "ports" {
  description = "Named ports exposed by the Sandbox. Names are serialized into the manifest and used for deterministic endpoint output."
  type = map(object({
    port      = number
    anonymous = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for item in values(var.ports) : item.port >= 1 && item.port <= 65535
    ])
    error_message = "Every port must be between 1 and 65535."
  }

  validation {
    condition     = length(distinct([for item in values(var.ports) : item.port])) == length(var.ports)
    error_message = "Every named port must use a unique port number."
  }
}

variable "primary_port_name" {
  description = "Name of the port used for primary_port_url, mcp_url, and health_url."
  type        = string
}

variable "mcp_path" {
  description = "Path appended to the primary port URL for mcp_url."
  type        = string
  default     = "/mcp"
}

variable "health_path" {
  description = "Path appended to the primary port URL for health_url."
  type        = string
  default     = "/health"
}

variable "aca_cli_path" {
  description = "ACA CLI executable. Version 1.0.0-beta.1 is required."
  type        = string
  default     = "aca"
}

variable "disk_ready_timeout_seconds" {
  description = "Maximum time to wait for a newly imported disk to become ready."
  type        = number
  default     = 600

  validation {
    condition     = var.disk_ready_timeout_seconds >= 30
    error_message = "disk_ready_timeout_seconds must be at least 30."
  }
}

variable "registry_auth_retry_timeout_seconds" {
  description = "Maximum time to retry authentication-related managed-identity disk import failures before failing or using the explicitly enabled token fallback."
  type        = number
  default     = 120

  validation {
    condition     = var.registry_auth_retry_timeout_seconds >= 0 && var.registry_auth_retry_timeout_seconds <= 600
    error_message = "registry_auth_retry_timeout_seconds must be between 0 and 600 seconds."
  }
}
