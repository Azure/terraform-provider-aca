locals {
  # Extract the VNet name from an existing VNet resource ID when create_vnet is false.
  existing_vnet_name = var.existing_vnet_id != null ? element(split("/", var.existing_vnet_id), length(split("/", var.existing_vnet_id)) - 1) : null

  vnet_name           = var.create_vnet ? azurerm_virtual_network.this[0].name : local.existing_vnet_name
  vnet_resource_group = var.resource_group_name
}

# -------------------------------------------------------------------
# Virtual Network (created only when var.create_vnet == true)
# -------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  count = var.create_vnet ? 1 : 0

  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.existing_vnet_id == null || var.existing_vnet_id == ""
      error_message = "Cannot set existing_vnet_id when create_vnet is true. Set create_vnet = false to use an existing VNet."
    }
  }
}

# -------------------------------------------------------------------
# Subnet for ACA environment
# ACA sets the Microsoft.App/environments delegation itself during
# environment provisioning. We must NOT pre-delegate the subnet or
# environment creation will fail with ManagedEnvironmentSubnetIsDelegated.
# -------------------------------------------------------------------
resource "azurerm_subnet" "aca" {
  name                 = "${var.name_prefix}-aca-subnet"
  resource_group_name  = local.vnet_resource_group
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.aca_subnet_address_prefix]

  lifecycle {
    ignore_changes = [delegation]
  }
}

# -------------------------------------------------------------------
# Network Security Group (created only when var.create_nsg == true)
# -------------------------------------------------------------------
resource "azurerm_network_security_group" "this" {
  count = var.create_nsg ? 1 : 0

  name                = "${var.name_prefix}-aca-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -------------------------------------------------------------------
# Custom NSG rules
# -------------------------------------------------------------------
resource "azurerm_network_security_rule" "custom" {
  for_each = { for rule in(var.create_nsg ? var.nsg_rules : []) : rule.name => rule }

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[0].name
}

# -------------------------------------------------------------------
# Associate NSG with ACA subnet
# -------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "this" {
  count = var.create_nsg ? 1 : 0

  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.this[0].id
}
