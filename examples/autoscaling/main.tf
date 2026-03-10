# Autoscaling Example — Terraform ACA Extension Layer
#
# Demonstrates advanced autoscaling with HTTP concurrency rules and custom
# KEDA scalers. Uses sub-modules directly so that AzAPI overlay resources
# can add scale rules that the typed template variable does not include.

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

locals {
  tags = {
    Pattern   = "Autoscaling"
    ManagedBy = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

module "observability" {
  source = "../../modules/observability"

  name_prefix         = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  create_log_analytics_workspace = true
  tags                           = local.tags
}

# ---------------------------------------------------------------------------
# ACA Environment
# ---------------------------------------------------------------------------

module "environment" {
  source = "../../modules/container_app_environment"

  name                       = var.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  tags                       = local.tags
}

# ---------------------------------------------------------------------------
# Web App — HTTP concurrency scaling via AzAPI overlay
# ---------------------------------------------------------------------------

module "web_app" {
  source = "../../modules/container_app"

  name                         = "${var.name}-web"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.environment.id
  revision_mode                = "Single"

  template = {
    min_replicas = 0
    max_replicas = 20
    containers = [{
      name   = "web"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
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

  tags = local.tags
}

resource "azapi_update_resource" "web_scaling" {
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = module.web_app.id

  body = {
    properties = {
      template = {
        scale = {
          minReplicas = 0
          maxReplicas = 20
          rules = [{
            name = "http-scaling"
            http = {
              metadata = {
                concurrentRequests = tostring(var.http_concurrency_threshold)
              }
            }
          }]
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Worker App — Azure Service Bus queue scaling via KEDA + AzAPI overlay
# ---------------------------------------------------------------------------

module "worker_app" {
  source = "../../modules/container_app"

  name                         = "${var.name}-worker"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.environment.id
  revision_mode                = "Single"

  template = {
    min_replicas = 0
    max_replicas = 10
    containers = [{
      name   = "worker"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
    }]
  }

  tags = local.tags
}

resource "azapi_update_resource" "worker_scaling" {
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = module.worker_app.id

  body = {
    properties = {
      template = {
        scale = {
          minReplicas = 0
          maxReplicas = 10
          rules = [{
            name = "queue-scaling"
            custom = {
              type = "azure-servicebus"
              metadata = {
                queueName    = var.servicebus_queue_name
                messageCount = tostring(var.servicebus_message_count)
                namespace    = var.servicebus_namespace
              }
            }
          }]
        }
      }
    }
  }
}
