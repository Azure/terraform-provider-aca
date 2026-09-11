terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.50.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "sandbox" {
  name                 = "sandbox-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.50.0.0/23"]

  delegation {
    name = "sandbox-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  lifecycle {
    ignore_changes = [delegation]
  }
}

module "sandbox_group" {
  source = "../../modules/sandbox_groups"

  depends_on = [azurerm_subnet.sandbox]

  name              = var.name
  resource_group_id = azurerm_resource_group.this.id
  location          = azurerm_resource_group.this.location
  api_profile       = var.api_profile

  default_cpu             = var.api_profile == "rich_preview" ? var.default_cpu : null
  default_memory          = var.api_profile == "rich_preview" ? var.default_memory : null
  default_disk            = var.api_profile == "rich_preview" ? var.default_disk : null
  max_sandbox_count       = var.api_profile == "rich_preview" ? var.max_sandbox_count : null
  default_timeout_seconds = var.api_profile == "rich_preview" ? var.default_timeout_seconds : null

  identity = var.api_profile == "rich_preview" ? {
    type = "SystemAssigned"
  } : null

  vnet_connections = {
    primary = {
      subnet_id = azurerm_subnet.sandbox.id
    }
  }

  data_plane_operators = {
    terraform_caller = {
      principal_id   = data.azurerm_client_config.current.object_id
      principal_type = "User"
    }
  }

  lock_enabled = var.lock_enabled
  tags         = var.tags
}
