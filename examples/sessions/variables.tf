variable "name" {
  description = "Base name for the sessions deployment."
  type        = string
  default     = "sessions-aca"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "sessions-aca-rg"
}

variable "location" {
  description = "Azure region. Must support ACA dynamic sessions."
  type        = string
  default     = "eastus2"
}

variable "max_concurrent_sessions" {
  description = "Maximum concurrent sessions in the pool."
  type        = number
  default     = 10
}

variable "ready_session_instances" {
  description = "Number of pre-warmed session instances."
  type        = number
  default     = 1
}

variable "session_pool_endpoint" {
  description = <<-EOT
    Management endpoint for the ACA dynamic session pool.
    Leave empty on initial apply. After the first apply, copy the
    session_pool_management_endpoint output here and re-apply to wire
    the SESSION_POOL_ENDPOINT environment variable in the container app.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}
