# Premium Ingress Example — Terraform ACA Extension Layer
#
# Demonstrates Premium Ingress via AzAPI overlay. Premium Ingress runs
# ingress proxies on a dedicated workload profile instead of shared
# infrastructure, giving operators control over SKU, autoscale range,
# and connection tuning parameters.
#
# This feature is GA in the ACA API (2025-07-01) but not yet supported
# by AzureRM. The module bridges the gap using azapi_update_resource.

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
# ACA Module — Environment with Premium Ingress
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

  environment = {
    feature_flags = {
      premium_ingress = true
    }

    ingress_configuration = {
      workload_profile_name            = var.ingress_profile_name
      workload_profile_type            = var.ingress_profile_type
      minimum_node_count               = var.ingress_min_nodes
      maximum_node_count               = var.ingress_max_nodes
      termination_grace_period_minutes = var.termination_grace_period_minutes
      request_idle_timeout             = var.request_idle_timeout
      header_count_limit               = var.header_count_limit
    }
  }

  container_apps = {
    api = {
      revision_mode = "Single"

      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "api"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"

          env = [
            { name = "APP_ENV", value = "production" },
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
  }
}
