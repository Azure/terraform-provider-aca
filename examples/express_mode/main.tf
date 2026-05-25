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
# ACA Module — Express Environment
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

  # NOTE: container_apps deliberately omitted here. AzureRM's
  # `azurerm_container_app` resource always emits `properties.template.containers.*.probes`
  # (even when no probe block is configured), and the Express runtime rejects
  # any request that contains `probes`:
  #   ExpressEnvironmentFeatureNotSupported: 'Probes' is not supported for ...
  # Until AzureRM exposes a way to omit the probes payload (or the Express RP
  # accepts an empty array), apps targeting Express environments must be
  # created via AzAPI directly. See the azapi_resource below.
}

# ---------------------------------------------------------------------------
# Sample Container App on the Express environment (via AzAPI)
# ---------------------------------------------------------------------------

resource "azapi_resource" "api" {
  type      = "Microsoft.App/containerApps@2025-10-02-preview"
  name      = "${var.name}-api"
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id

  body = {
    properties = {
      managedEnvironmentId = module.aca.environment_id
      configuration = {
        activeRevisionsMode = "Single"
        ingress = {
          external      = true
          targetPort    = 80
          transport     = "auto"
          traffic = [{
            latestRevision = true
            weight         = 100
          }]
        }
      }
      template = {
        containers = [{
          name      = "api"
          image     = var.container_image
          resources = { cpu = 0.25, memory = "0.5Gi" }
          env       = [{ name = "APP_MODE", value = "express" }]
        }]
        scale = {
          minReplicas = 1
          maxReplicas = 3
        }
      }
    }
  }

  response_export_values = ["properties.configuration.ingress.fqdn"]

  tags = var.tags
}
