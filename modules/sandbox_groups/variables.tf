# ---------------------------------------------------------------------------
# Required arguments
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of the Sandbox Group (Microsoft.App/sandboxGroups resource name)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,62}[a-zA-Z0-9]$", var.name))
    error_message = "Sandbox group name must be 2-64 characters, start with a letter, end alphanumeric, and contain only letters, digits, or hyphens."
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

# ---------------------------------------------------------------------------
# ARM resource sizing — defaults applied to every sandbox in the group.
# Tier hints from docs: XS (0.25 / 0.5Gi), S (0.5 / 1Gi), M (1 / 2Gi), L (2 / 4Gi).
# Disk is independent of the CPU/memory tier.
# ---------------------------------------------------------------------------

variable "default_cpu" {
  description = "Default vCPU per sandbox, expressed as a string (e.g. \"0.25\", \"0.5\", \"1\", \"2\")."
  type        = string
  default     = "1"
}

variable "default_memory" {
  description = "Default memory per sandbox (e.g. \"0.5Gi\", \"1Gi\", \"2Gi\", \"4Gi\", \"8Gi\")."
  type        = string
  default     = "2Gi"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.default_memory))
    error_message = "default_memory must be a Kubernetes-style memory string ending in 'Gi' (e.g. \"2Gi\")."
  }
}

variable "default_disk" {
  description = "Default ephemeral disk size per sandbox (e.g. \"20Gi\", \"32Gi\", \"50Gi\")."
  type        = string
  default     = "20Gi"

  validation {
    condition     = can(regex("^[0-9]+Gi$", var.default_disk))
    error_message = "default_disk must be an integer GiB value ending in 'Gi' (e.g. \"32Gi\")."
  }
}

variable "max_sandbox_count" {
  description = "Maximum number of concurrent sandboxes that can run inside the group."
  type        = number
  default     = 50

  validation {
    condition     = var.max_sandbox_count >= 1 && var.max_sandbox_count <= 1000
    error_message = "max_sandbox_count must be between 1 and 1000."
  }
}

variable "default_timeout_seconds" {
  description = "Default lifetime in seconds for a sandbox before the platform automatically tears it down."
  type        = number
  default     = 3600

  validation {
    condition     = var.default_timeout_seconds >= 60
    error_message = "default_timeout_seconds must be at least 60 seconds."
  }
}

# ---------------------------------------------------------------------------
# Optional network integration
# ---------------------------------------------------------------------------

variable "network_config" {
  description = <<-EOT
    Inline network configuration for the sandbox group. Either bring your own
    subnet or constrain public access. Mutually informative with `vnet_connections`:
    `network_config` is the simple single-subnet path; `vnet_connections` allows
    multiple named VNet integrations as child resources.

    Attributes:
      public_network_access - "Enabled" or "Disabled"
      subnet_id             - Resource ID of a delegated subnet (Microsoft.App/sandboxGroups)
  EOT
  type = object({
    public_network_access = optional(string)
    subnet_id             = optional(string)
  })
  default = null

  validation {
    condition = (
      var.network_config == null ||
      var.network_config.public_network_access == null ||
      contains(["Enabled", "Disabled"], var.network_config.public_network_access)
    )
    error_message = "network_config.public_network_access must be \"Enabled\" or \"Disabled\"."
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
# MCP / gateway connections (data-plane configuration surfaced via ARM)
# ---------------------------------------------------------------------------

variable "gateway_connections" {
  description = <<-EOT
    Optional list of gateway (MCP server) connections published to all sandboxes
    in the group. Each entry references an existing Microsoft.Web connector
    gateway and the auth mode used to reach it.
  EOT
  type = list(object({
    resource_id     = string
    mcp_runtime_url = optional(string)
    authentication = optional(object({
      type                 = string
      identity_resource_id = optional(string)
    }))
  }))
  default = []
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

variable "api_version" {
  description = "API version used for the Microsoft.App/sandboxGroups AzAPI resource. Override only if a newer preview version is required."
  type        = string
  default     = "2026-02-01-preview"
}
