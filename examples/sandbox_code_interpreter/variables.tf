variable "subscription_id" {
  description = "Azure subscription used by the example."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription GUID."
  }
}

variable "resource_group_name" {
  description = "Resource group created by the example."
  type        = string
  default     = "tf-aca-19"
}

variable "location" {
  description = "Azure region supporting rich-preview ACA Sandbox Groups."
  type        = string
  default     = "swedencentral"
}

variable "name_prefix" {
  description = "Naming prefix for example resources."
  type        = string
  default     = "aca-sandbox-code"
}

variable "sandbox_group_name" {
  description = "Sandbox Group resource name."
  type        = string
  default     = "aca-sandbox-code"
}

variable "sandbox_cpu" {
  description = "Sandbox workload CPU."
  type        = string
  default     = "2000m"
}

variable "sandbox_memory" {
  description = "Sandbox workload memory."
  type        = string
  default     = "4096Mi"
}

variable "sandbox_port" {
  description = "MCP and health server port."
  type        = number
  default     = 8080
}

variable "allow_registry_token_fallback" {
  description = "Explicitly permit short-lived ACR token fallback if managed-identity disk import fails for an authentication reason."
  type        = bool
  default     = false
}

variable "mcp_token_revision" {
  description = "Non-sensitive rotation identifier. Change this value when rotating the generated MCP token."
  type        = string
  default     = "v1"
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
