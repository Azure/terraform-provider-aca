variable "name" {
  description = "Name of the Container App Job."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the job."
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the Container App Environment."
  type        = string
}

variable "environment_mode" {
  description = "Mode of the target Container Apps environment."
  type        = string
  default     = "WorkloadProfiles"
}

variable "replica_timeout_in_seconds" {
  description = "Maximum number of seconds a replica is allowed to run."
  type        = number
}

variable "template" {
  description = "Job template configuration. Contains containers, init_containers, and volumes."
  type        = any
}

variable "workload_profile_name" {
  description = "Name of the workload profile to use."
  type        = string
  default     = null
}

variable "replica_retry_limit" {
  description = "Maximum number of retries for a failed replica."
  type        = number
  default     = 0
}

variable "schedule_trigger_config" {
  description = "Schedule trigger configuration (cron expression, parallelism, replica completion count)."
  type        = any
  default     = null
}

variable "event_trigger_config" {
  description = "Event-driven trigger configuration."
  type        = any
  default     = null
}

variable "manual_trigger_config" {
  description = "Manual trigger configuration."
  type        = any
  default     = null
}

variable "registry" {
  description = "Container registry authentication configurations."
  type        = list(any)
  default     = []
}

variable "secret" {
  description = "Secret definitions for the job."
  type        = list(any)
  default     = []
}

variable "identity" {
  description = "Managed identity configuration."
  type        = any
  default     = null
}

variable "tags" {
  description = "Tags to apply to the job."
  type        = map(string)
  default     = {}
}

variable "feature_flags" {
  description = "Enable preview features for ACA Jobs (uses AzAPI under the hood)."
  type = object({
    event_trigger_advanced = optional(bool, false)
  })
  default = {}
}

variable "provider_overrides" {
  description = "Override provider routing for specific features. Map of feature name to provider (azurerm or azapi)."
  type        = map(string)
  default     = {}
}
