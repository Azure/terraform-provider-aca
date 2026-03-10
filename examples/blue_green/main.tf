# Blue/Green Deployment Example — Terraform ACA Extension Layer
#
# Demonstrates blue/green deployments with multiple revision mode, traffic
# splitting, and revision labels on Azure Container Apps.

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

  observability = {
    log_analytics_retention_in_days = 30
    create_application_insights     = true
  }

  container_apps = {
    web = {
      revision_mode = "Multiple"
      template = {
        min_replicas    = 1
        max_replicas    = 10
        revision_suffix = var.revision_suffix
        containers = [{
          name   = "web"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"
          env = [
            { name = "APP_VERSION", value = var.app_version },
          ]
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [
          {
            latest_revision = true
            percentage      = 100
            label           = "latest"
          },
        ]
      }
    }
  }
}
