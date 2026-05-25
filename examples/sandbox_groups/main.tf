# Sandbox Groups Example — Terraform ACA Extension Layer
#
# Demonstrates ACA Sandboxes, a new ACA product that provisions pools of
# disposable Linux VMs ("sandboxes") for AI agent code execution, untrusted
# code isolation, and per-tenant ephemeral compute.
#
# This example creates:
#   - A delegated VNet/subnet for sandbox networking
#   - A Microsoft.App/sandboxGroups resource via AzAPI (no AzureRM support)
#   - A child Microsoft.App/sandboxGroups/vnetConnections for the subnet
#   - System-assigned managed identity on the group
#
# Note: Individual sandboxes are data-plane resources (management.{region}.
# azuredevcompute.io) and are NOT ARM-managed. After apply, drive sandbox
# lifecycle from the `management_endpoint` output via the ACA CLI or SDK.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# VNet + delegated subnet for sandbox networking
# ---------------------------------------------------------------------------

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

  # Sandbox groups apply their own subnet delegation
  # (Microsoft.App/sandboxGroups) at provision time. AzureRM's allow-list does
  # not yet include this delegation name, so leave it unset here and let the
  # platform manage it. Drift on the delegation block is expected.
  lifecycle {
    ignore_changes = [delegation]
  }
}

# ---------------------------------------------------------------------------
# ACA Module — Sandbox Group via the top-level sandbox_groups map
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  depends_on = [azurerm_subnet.sandbox]

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  sandbox_groups = {
    agents = {
      default_cpu             = var.default_cpu
      default_memory          = var.default_memory
      default_disk            = var.default_disk
      max_sandbox_count       = var.max_sandbox_count
      default_timeout_seconds = var.default_timeout_seconds

      identity = {
        type = "SystemAssigned"
      }

      vnet_connections = {
        primary = {
          subnet_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.this.name}/providers/Microsoft.Network/virtualNetworks/${azurerm_virtual_network.this.name}/subnets/${azurerm_subnet.sandbox.name}"
        }
      }

      tags = {
        purpose = "agent-code-execution"
      }
    }
  }
}
