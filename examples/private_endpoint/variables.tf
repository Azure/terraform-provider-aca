variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-private"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-8"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "container_image" {
  description = "Container image for the private app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
