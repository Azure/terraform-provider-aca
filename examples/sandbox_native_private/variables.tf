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
  default     = "tf-aca-21"
}

variable "location" {
  description = "Azure region supporting ACA Sandboxes."
  type        = string
  default     = "swedencentral"
}

variable "sandbox_group_name" {
  description = "Sandbox Group resource name."
  type        = string
  default     = "aca-sbox-native-private"
}

variable "sandbox_name" {
  description = "Logical Terraform name for the data-plane Sandbox."
  type        = string
  default     = "private-azurelinux"
}

variable "source_image" {
  description = "Public image imported into the example ACR."
  type        = string
  default     = "azurelinux/base/core:3.0"
}

variable "target_image" {
  description = "Repository and tag created in the example ACR."
  type        = string
  default     = "samples/azurelinux:3.0"
}

variable "tags" {
  description = "Tags applied to ARM resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "sandbox-native-private"
  }
}
