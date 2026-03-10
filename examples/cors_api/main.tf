# CORS API Example — Terraform ACA Extension Layer
#
# Demonstrates CORS policy configuration for an API backend serving a
# frontend SPA. Uses azapi_update_resource to patch CORS onto the API
# app after module deployment — the module's container_app template type
# does not include a cors_policy field, and azurerm only added CORS
# support for Container Apps in June 2025 (2+ years after GA in the API).

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
# ACA Module — API + Frontend Apps
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  observability = {
    log_analytics_retention_in_days = 30
  }

  container_apps = {

    # Backend API: CORS will be patched on after deployment
    api = {
      revision_mode = "Single"
      template = {
        min_replicas = 1
        max_replicas = 10
        containers = [{
          name   = "api"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"
          env = [
            { name = "CORS_ENABLED", value = "true" },
          ]
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [{ latest_revision = true, percentage = 100 }]
      }
    }

    # Frontend SPA: serves the browser app that calls the API
    frontend = {
      revision_mode = "Single"
      template = {
        min_replicas = 1
        max_replicas = 5
        containers = [{
          name   = "frontend"
          image  = var.container_image
          cpu    = 0.25
          memory = "0.5Gi"
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [{ latest_revision = true, percentage = 100 }]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# CORS Policy — applied via AzAPI after module creates the API app
# ---------------------------------------------------------------------------
# The module does not expose a cors_policy field on the container_app
# template. We use azapi_update_resource to patch the CORS configuration
# onto the API app's ingress after it has been created.

resource "azapi_update_resource" "api_cors" {
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = module.aca.container_apps["api"].id

  body = {
    properties = {
      configuration = {
        ingress = {
          corsPolicy = {
            allowedOrigins   = var.cors_allowed_origins
            allowedMethods   = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
            allowedHeaders   = ["*"]
            exposeHeaders    = ["X-Request-Id"]
            maxAge           = 3600
            allowCredentials = true
          }
        }
      }
    }
  }
}
