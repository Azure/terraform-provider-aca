variable "name" {
  description = "Base name for the deployment."
  type        = string
  default     = "aca-simple"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "aca-simple-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
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
  description = "Container image for the hello-world app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aca_subnet_address_prefix" {
  description = "Subnet CIDR for the ACA environment (must be /23 or larger)."
  type        = string
  default     = "10.0.0.0/23"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "min_replicas" {
  description = "Minimum number of container replicas."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum number of container replicas."
  type        = number
  default     = 3
}
