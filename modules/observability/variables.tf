variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for resources."
  type        = string
}

variable "create_log_analytics_workspace" {
  description = "Whether to create a new Log Analytics workspace."
  type        = bool
  default     = true
}

variable "existing_log_analytics_workspace_id" {
  description = "ID of an existing Log Analytics workspace to use instead of creating a new one."
  type        = string
  default     = null
}

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  description = "Retention period in days for the Log Analytics workspace."
  type        = number
  default     = 30
}

variable "create_application_insights" {
  description = "Whether to create an Application Insights instance."
  type        = bool
  default     = false
}

variable "application_insights_type" {
  description = "Type of Application Insights to create."
  type        = string
  default     = "web"
}

variable "diagnostic_settings" {
  description = "List of diagnostic settings to create."
  type = list(object({
    name               = string
    target_resource_id = string
    log_categories     = list(string)
    metric_categories  = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
