variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-sandbox"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-18"
}

variable "location" {
  description = "Azure region. Must support Microsoft.App/sandboxGroups (e.g. swedencentral, eastus2, westus3)."
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "SandboxGroups"
  }
}

# ---------------------------------------------------------------------------
# Sandbox tier — matches the documented M tier (1 vCPU / 2Gi memory)
# bumped up to give agent workloads enough headroom for code execution.
# ---------------------------------------------------------------------------

variable "default_cpu" {
  description = "Default vCPU per sandbox."
  type        = string
  default     = "2"
}

variable "default_memory" {
  description = "Default memory per sandbox."
  type        = string
  default     = "4Gi"
}

variable "default_disk" {
  description = "Default ephemeral disk per sandbox."
  type        = string
  default     = "32Gi"
}

variable "max_sandbox_count" {
  description = "Maximum number of concurrent sandboxes in the group."
  type        = number
  default     = 50
}

variable "default_timeout_seconds" {
  description = "Auto-teardown timeout for idle sandboxes."
  type        = number
  default     = 3600
}
