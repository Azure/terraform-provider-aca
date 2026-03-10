# Dynamic Sessions Example — Terraform ACA Extension Layer
#
# Demonstrates ACA Dynamic Sessions (code interpreter) with:
# - Session pool via AzAPI (not yet in AzureRM)
# - Python code interpreter session type
# - Container app that interacts with sessions

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
}

# ---------------------------------------------------------------------------
# ACA Module — Environment + App
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = {
    Pattern   = "DynamicSessions"
    ManagedBy = "Terraform"
  }

  observability = {
    create_log_analytics_workspace = true
  }

  environment = {}

  container_apps = {
    session-client = {
      revision_mode = "Single"

      template = {
        min_replicas = 1
        max_replicas = 3

        containers = [
          {
            name   = "client"
            image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
            cpu    = 0.5
            memory = "1Gi"

            env = [
              # SESSION_POOL_ENDPOINT: set var.session_pool_endpoint to the
              # session_pool_management_endpoint output after the first apply.
              # A direct reference to azapi_resource.session_pool.output would
              # create a circular dependency (pool depends on environment_id).
              { name = "SESSION_POOL_ENDPOINT", value = var.session_pool_endpoint },
            ]
          }
        ]
      }

      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [
          { latest_revision = true, percentage = 100 }
        ]
      }

      identity = {
        type = "SystemAssigned"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Dynamic Sessions Pool (AzAPI — not yet supported in AzureRM)
# ---------------------------------------------------------------------------

resource "azapi_resource" "session_pool" {
  type      = "Microsoft.App/sessionPools@2024-10-02-preview"
  name      = replace("${var.name}sessions", "-", "")
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id

  body = {
    properties = {
      environmentId      = module.aca.environment_id
      poolManagementType = "Dynamic"
      containerType      = "PythonLTS"
      scaleConfiguration = {
        maxConcurrentSessions = var.max_concurrent_sessions
        readySessionInstances = var.ready_session_instances
      }
      dynamicPoolConfiguration = {
        executionType           = "Timed"
        cooldownPeriodInSeconds = 300
      }
    }
  }

  response_export_values = ["properties.poolManagementEndpoint"]

  tags = {
    Pattern   = "DynamicSessions"
    ManagedBy = "Terraform"
  }
}
