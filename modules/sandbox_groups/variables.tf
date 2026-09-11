# ---------------------------------------------------------------------------
# Required arguments
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of the Sandbox Group (Microsoft.App/sandboxGroups resource name)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,32}$", var.name)) && !startswith(var.name, "-")
    error_message = "Sandbox group name must be 1-32 characters, contain only letters, digits, or hyphens, and cannot start with a hyphen."
  }
}

variable "resource_group_id" {
  description = "Full resource ID of the resource group the sandbox group will live in (used as `parent_id` for AzAPI)."
  type        = string
}

variable "location" {
  description = "Azure region where the sandbox group is created."
  type        = string
}

variable "api_profile" {
  description = "Sandbox Group field profile: stable is the minimal default shape; rich_preview enables documented preview defaults and identity. Both default to the deployed 2026-02-01-preview API."
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "rich_preview"], var.api_profile)
    error_message = "api_profile must be stable or rich_preview."
  }
}

variable "environment_id" {
  description = "Optional Container Apps environment ID for the stable profile. Requires api_version to be set explicitly to a registered contract that exposes environmentId; once linked, the service does not allow changing or removing it."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# ARM resource sizing — defaults applied to every sandbox in the group.
# Tier hints from docs: XS (0.25 / 0.5Gi), S (0.5 / 1Gi), M (1 / 2Gi), L (2 / 4Gi).
# Disk is independent of the CPU/memory tier.
# ---------------------------------------------------------------------------

variable "default_cpu" {
  description = "Default vCPU per sandbox, expressed as a string (e.g. \"0.25\", \"0.5\", \"1\", \"2\")."
  type        = string
  default     = null
}

variable "default_memory" {
  description = "Default memory per sandbox (e.g. \"0.5Gi\", \"1Gi\", \"2Gi\", \"4Gi\", \"8Gi\")."
  type        = string
  default     = null

  validation {
    condition     = var.default_memory == null || can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.default_memory))
    error_message = "default_memory must be a Kubernetes-style memory string ending in 'Gi' (e.g. \"2Gi\")."
  }
}

variable "default_disk" {
  description = "Default ephemeral disk size per sandbox (e.g. \"20Gi\", \"32Gi\", \"50Gi\")."
  type        = string
  default     = null

  validation {
    condition     = var.default_disk == null || can(regex("^[0-9]+Gi$", var.default_disk))
    error_message = "default_disk must be an integer GiB value ending in 'Gi' (e.g. \"32Gi\")."
  }
}

variable "max_sandbox_count" {
  description = "Maximum number of concurrent sandboxes that can run inside the group."
  type        = number
  default     = null

  validation {
    condition     = var.max_sandbox_count == null || (var.max_sandbox_count >= 1 && var.max_sandbox_count <= 1000)
    error_message = "max_sandbox_count must be between 1 and 1000."
  }
}

variable "default_timeout_seconds" {
  description = "Default lifetime in seconds for a sandbox before the platform automatically tears it down."
  type        = number
  default     = null

  validation {
    condition     = var.default_timeout_seconds == null || var.default_timeout_seconds >= 60
    error_message = "default_timeout_seconds must be at least 60 seconds."
  }
}

# ---------------------------------------------------------------------------
# Managed identity
# ---------------------------------------------------------------------------

variable "identity" {
  description = <<-EOT
    Managed identity configuration. Set type = "SystemAssigned" for a
    platform-managed identity, "UserAssigned" to attach existing identities,
    "SystemAssigned, UserAssigned" for both, or null/None to disable.

    Attributes:
      type         - "SystemAssigned" | "UserAssigned" | "SystemAssigned, UserAssigned" | "None"
      identity_ids - Resource IDs of user-assigned managed identities
  EOT
  type = object({
    type         = string
    identity_ids = optional(list(string), [])
  })
  default = null

  validation {
    condition = (
      var.identity == null ||
      contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned", "None"], var.identity.type)
    )
    error_message = "identity.type must be one of: SystemAssigned, UserAssigned, SystemAssigned, UserAssigned, None."
  }
}

# ---------------------------------------------------------------------------
# Child resource: VNet connections
# ---------------------------------------------------------------------------

variable "vnet_connections" {
  description = <<-EOT
    Map of `Microsoft.App/sandboxGroups/vnetConnections` child resources keyed
    by connection name. Each entry binds the group to an additional subnet.
  EOT
  type = map(object({
    subnet_id = string
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Common
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to the sandbox group."
  type        = map(string)
  default     = {}
}

variable "data_plane_operators" {
  description = "Map of principals to grant the Container Apps SandboxGroup Data Owner role."
  type = map(object({
    principal_id                     = string
    principal_type                   = optional(string)
    skip_service_principal_aad_check = optional(bool, false)
  }))
  default = {}
}

variable "acr_pull_assignments" {
  description = "Map of ACR scopes where the Sandbox Group identity should receive AcrPull. principal_id may override the system-assigned identity."
  type = map(object({
    scope                            = string
    principal_id                     = optional(string)
    skip_service_principal_aad_check = optional(bool, true)
  }))
  default = {}
}

variable "lock_enabled" {
  description = "Create a CanNotDelete management lock on the Sandbox Group."
  type        = bool
  default     = false
}

variable "lock_name" {
  description = "Name of the optional Sandbox Group management lock."
  type        = string
  default     = "protect-sandbox-group"
}

variable "api_version" {
  description = "Optional API version override. Both profiles default to the currently deployed 2026-02-01-preview contract."
  type        = string
  default     = null
}
