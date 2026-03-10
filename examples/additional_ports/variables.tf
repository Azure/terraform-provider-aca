variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-ports"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-11"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

variable "container_image" {
  description = "Container image for the API gateway app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
