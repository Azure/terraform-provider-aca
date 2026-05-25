# Express Mode Example — Terraform ACA Extension Layer
#
# Demonstrates ACA Express, the fully serverless mode of
# Microsoft.App/managedEnvironments. Express environments require no VNet,
# no workload profiles, and no Log Analytics workspace — the platform manages
# all infrastructure. The only ARM-level difference vs. a standard environment
# is `properties.environmentMode = "Express"`, which is silently dropped by GA
# API versions. The module applies it via an AzAPI overlay on a preview API.

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
# ACA Module — Express Environment + Sample App
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  # Express environments are public-facing and fully managed: no VNet, no LAW,
  # no workload profiles. Skip the networking and observability sub-modules.
  environment = {
    feature_flags = {
      express_mode = true
    }
  }

  container_apps = {
    api = {
      revision_mode = "Single"

      template = {
        min_replicas = 1
        max_replicas = 3

        containers = [{
          name   = "api"
          image  = var.container_image
          cpu    = 0.25
          memory = "0.5Gi"

          env = [
            { name = "APP_MODE", value = "express" },
          ]
        }]
      }

      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight   = [{ latest_revision = true, percentage = 100 }]
      }
    }
  }
}
