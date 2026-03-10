# Networking Module

Creates networking resources for Azure Container Apps (ACA) environment integration:

- **Virtual Network** – optionally created or referenced from an existing VNet.
- **Subnet** – dedicated subnet with the `Microsoft.App/environments` delegation required by ACA (minimum /23 CIDR).
- **Network Security Group** – optional NSG with custom rules, automatically associated with the ACA subnet.

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  name_prefix         = "myapp"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  vnet_address_space        = ["10.0.0.0/16"]
  aca_subnet_address_prefix = "10.0.0.0/23"

  tags = {
    Environment = "dev"
  }
}
```

### Using an existing VNet

```hcl
module "networking" {
  source = "./modules/networking"

  name_prefix         = "myapp"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  create_vnet     = false
  existing_vnet_id = azurerm_virtual_network.existing.id

  aca_subnet_address_prefix = "10.0.2.0/23"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `vnet_id` | ID of the virtual network |
| `subnet_id` | ID of the ACA subnet |
| `nsg_id` | ID of the network security group (null if not created) |
