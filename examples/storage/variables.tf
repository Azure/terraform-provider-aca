variable "name" {
  description = "Base name for the storage deployment."
  type        = string
  default     = "storage-aca"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "storage-aca-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account (must be globally unique, 3-24 lowercase alphanumeric)."
  type        = string
  default     = "tfaca6stordata"
}

variable "share_quota_gb" {
  description = "Quota in GB for the data file share."
  type        = number
  default     = 5
}
