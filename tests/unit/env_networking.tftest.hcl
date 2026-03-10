# ---------------------------------------------------------------------------
# Environment — Networking Integration Test
# ---------------------------------------------------------------------------
# Validates that the networking module creates VNet, subnet, and NSG resources
# with correct configuration.

variables {
  name_prefix               = "test-net"
  resource_group_name       = "rg-test"
  location                  = "eastus"
  create_vnet               = true
  vnet_address_space        = ["10.0.0.0/16"]
  aca_subnet_address_prefix = "10.0.0.0/23"
  create_nsg                = true
  nsg_rules                 = []
  tags                      = { Environment = "test" }
}

run "networking_creates_vnet" {
  command = plan

  module {
    source = "../../modules/networking"
  }

  assert {
    condition     = azurerm_virtual_network.this[0].name == "test-net-vnet"
    error_message = "VNet name should follow naming convention."
  }

  assert {
    condition     = azurerm_virtual_network.this[0].address_space == tolist(["10.0.0.0/16"])
    error_message = "VNet address space should match input."
  }
}

run "networking_creates_nsg" {
  command = plan

  module {
    source = "../../modules/networking"
  }

  assert {
    condition     = azurerm_network_security_group.this[0].name == "test-net-aca-nsg"
    error_message = "NSG name should follow naming convention."
  }
}

run "networking_delegates_subnet" {
  command = plan

  module {
    source = "../../modules/networking"
  }

  assert {
    condition     = azurerm_subnet.aca.name == "test-net-aca-subnet"
    error_message = "Subnet name should follow naming convention."
  }

  assert {
    condition     = length(azurerm_subnet.aca.delegation) > 0
    error_message = "Subnet should have a delegation for Microsoft.App/environments."
  }
}
