variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-cors"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-13"
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
  description = "Container image for both the API and frontend apps."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "cors_allowed_origins" {
  description = "List of origins allowed to make cross-origin requests to the API."
  type        = list(string)
  default     = ["https://example.com"]
}
