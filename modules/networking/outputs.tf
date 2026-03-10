output "vnet_id" {
  description = "The ID of the virtual network."
  value       = var.create_vnet ? azurerm_virtual_network.this[0].id : var.existing_vnet_id
}

output "subnet_id" {
  description = "The ID of the ACA subnet."
  value       = azurerm_subnet.aca.id

  depends_on = [
    azurerm_subnet_network_security_group_association.this
  ]
}

output "nsg_id" {
  description = "The ID of the network security group."
  value       = var.create_nsg ? azurerm_network_security_group.this[0].id : null
}
