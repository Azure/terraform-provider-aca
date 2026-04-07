# Sticky Sessions Example — Terraform ACA Extension Layer
#
# Demonstrates sticky sessions via AzAPI overlay — the #1 missing feature
# from azurerm (GA since May 2023, 670+ days without provider support).
# Uses the module's feature_flags pattern to apply sticky session affinity
# through AzAPI while keeping everything else on AzureRM.

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
# ACA Module — Environment + Cart App with Sticky Sessions
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  observability = {
    create_log_analytics_workspace = true
  }

  container_apps = {
    cart = {
      revision_mode = "Single"

      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "cart-app"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"

          env = [
            { name = "SESSION_STORE", value = "in-memory" },
          ]
        }]
      }

      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [{ latest_revision = true, percentage = 100 }]
      }

      feature_flags = {
        sticky_sessions = true
      }
    }
  }
}
