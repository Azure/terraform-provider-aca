variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-express"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-17"
}

variable "location" {
  description = "Azure region. Must be an Express-supported region (e.g. westcentralus, eastasia, northcentralus)."
  type        = string
  default     = "northcentralus"
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "ExpressMode"
  }
}

variable "container_image" {
  description = "Container image for the sample app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
