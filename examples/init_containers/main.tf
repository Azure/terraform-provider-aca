# Init Containers Example — Terraform ACA Extension Layer
#
# Demonstrates init containers for database migration / pre-flight setup.
# The init container runs to completion before the main container starts,
# using a shared EmptyDir volume to signal migration status.

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
# ACA Module — Web App with Init Container
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

    # Web app with an init container for DB migration
    web = {
      revision_mode = "Single"
      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "web"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"
          env = [
            { name = "MIGRATION_STATUS_PATH", value = "/shared/migration-complete" },
          ]
          volume_mounts = [
            { name = "shared", path = "/shared" }
          ]
        }]

        init_containers = [{
          name   = "db-migrate"
          image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
          cpu    = 0.25
          memory = "0.5Gi"
          env = [
            { name = "MIGRATION_MODE", value = "apply" },
            { name = "DB_HOST", value = "placeholder-db.database.azure.com" },
          ]
          volume_mounts = [
            { name = "shared", path = "/shared" }
          ]
        }]

        volumes = [{
          name         = "shared"
          storage_type = "EmptyDir"
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
