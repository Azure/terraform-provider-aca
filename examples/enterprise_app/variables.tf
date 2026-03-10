variable "name" {
  description = "Base name for the ACA deployment."
  type        = string
  default     = "enterprise-aca"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "enterprise-aca-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Deployment environment (e.g., Production, Staging)."
  type        = string
  default     = "Production"
}

variable "cost_center" {
  description = "Cost center tag for billing."
  type        = string
  default     = "engineering"
}

variable "container_image" {
  description = "Container image for the API app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "aca_subnet_address_prefix" {
  description = "Subnet CIDR for the ACA environment (must be /23 or larger)."
  type        = string
  default     = "10.1.0.0/23"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "min_replicas" {
  description = "Minimum number of container replicas."
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas."
  type        = number
  default     = 5
}
