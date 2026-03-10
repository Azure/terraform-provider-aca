# Additional Ports Example — Terraform ACA Extension Layer
#
# Demonstrates multiple port mappings via the module's feature_flags pattern.
# The primary ingress serves HTTP on port 80; an additional mapping exposes
# gRPC on port 50051 through an AzAPI overlay.

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

  # VNet required for external additional port mappings
  networking = {
    vnet_address_space        = ["10.11.0.0/16"]
    aca_subnet_address_prefix = "10.11.0.0/23"
  }

  observability = {
    log_analytics_retention_in_days = 30
  }

  container_apps = {
    api-gateway = {
      revision_mode = "Single"
      template = {
        min_replicas = 1
        max_replicas = 5
        containers = [{
          name   = "gateway"
          image  = var.container_image
          cpu    = 1.0
          memory = "2Gi"
          env = [
            { name = "HTTP_PORT", value = "80" },
            { name = "GRPC_PORT", value = "50051" },
          ]
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [{
          latest_revision = true
          percentage      = 100
        }]
      }
      feature_flags = {
        advanced_ingress = true
      }
      additional_port_mappings = [
        {
          external     = true
          target_port  = 50051
          exposed_port = 50051
        }
      ]
    }
  }
}
