variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the resources."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aca_subnet_address_prefix" {
  description = "Address prefix for the ACA subnet. Must be at least /23 for ACA."
  type        = string
  default     = "10.0.0.0/23"
}

variable "create_vnet" {
  description = "Set to false to use an existing VNet instead of creating a new one."
  type        = bool
  default     = true
}

variable "existing_vnet_id" {
  description = "ID of an existing VNet to use when create_vnet is false."
  type        = string
  default     = null
}

variable "create_nsg" {
  description = "Whether to create a network security group for the ACA subnet."
  type        = bool
  default     = true
}

variable "nsg_rules" {
  description = "List of custom NSG rules to create."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
