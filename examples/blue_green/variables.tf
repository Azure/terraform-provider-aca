variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-bluegreen"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "tf-aca-12"
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
  description = "Container image for the web app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "revision_suffix" {
  description = "Suffix appended to the revision name. Change this to create a new revision (e.g. v1, v2)."
  type        = string
  default     = "v1"
}

variable "app_version" {
  description = "Application version passed to the container as APP_VERSION env var."
  type        = string
  default     = "1.0.0"
}
