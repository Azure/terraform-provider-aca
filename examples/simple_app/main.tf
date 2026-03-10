terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# ACA Module
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  networking = {
    vnet_address_space        = var.vnet_address_space
    aca_subnet_address_prefix = var.aca_subnet_address_prefix
  }

  observability = {
    log_analytics_retention_in_days = 30
  }

  container_apps = {
    hello = {
      revision_mode = "Single"
      template = {
        containers = [{
          name   = "hello"
          image  = var.container_image
          cpu    = 0.25
          memory = "0.5Gi"
        }]
        max_replicas = var.max_replicas
        min_replicas = var.min_replicas
      }
      ingress = {
        external_enabled = true
        target_port      = var.container_port
        transport        = "auto"
        traffic_weight = [{
          latest_revision = true
          percentage      = 100
        }]
      }
    }
  }
}
