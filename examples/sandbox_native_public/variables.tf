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
  default     = "tf-aca-20"
}

variable "location" {
  description = "Azure region supporting ACA Sandboxes."
  type        = string
  default     = "swedencentral"
}

variable "sandbox_group_name" {
  description = "Sandbox Group resource name."
  type        = string
  default     = "aca-sbox-native-public"
}

variable "sandbox_name" {
  description = "Logical Terraform name for the data-plane Sandbox."
  type        = string
  default     = "public-ubuntu"
}

variable "tags" {
  description = "Tags applied to ARM resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "sandbox-native-public"
  }
}
