variable "name" {
  description = "Base name for the jobs deployment."
  type        = string
  default     = "jobs-aca"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "jobs-aca-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "cleanup_job_image" {
  description = "Container image for the cleanup job."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "queue_processor_image" {
  description = "Container image for the queue processor job."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "db_connection_string" {
  description = "Database connection string for the cleanup job."
  type        = string
  sensitive   = true
  default     = ""
}

variable "queue_connection_string" {
  description = "Azure Storage Queue connection string."
  type        = string
  sensitive   = true
  default     = ""
}

variable "queue_name" {
  description = "Name of the Azure Storage Queue to process."
  type        = string
  default     = "work-items"
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account."
  type        = string
  default     = "mystorageaccount"
}

variable "cleanup_cron_expression" {
  description = "CRON expression for the cleanup job schedule."
  type        = string
  default     = "0 * * * *"
}

variable "cleanup_timeout_seconds" {
  description = "Maximum seconds a cleanup job replica may run."
  type        = number
  default     = 1800
}

variable "queue_timeout_seconds" {
  description = "Maximum seconds a queue-processor job replica may run."
  type        = number
  default     = 600
}

variable "queue_replica_retry_limit" {
  description = "Maximum retry attempts for a failed queue-processor replica."
  type        = number
  default     = 3
}
