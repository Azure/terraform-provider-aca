# Microservices Example — Terraform ACA Extension Layer
#
# Demonstrates a microservices architecture with:
# - Multiple container apps (frontend, backend-api, worker)
# - Dapr for service-to-service communication
# - Internal and external ingress
# - Scaling rules
# - Shared secrets

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
# ACA Module — Microservices
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = {
    Pattern   = "Microservices"
    ManagedBy = "Terraform"
  }

  # Observability for distributed tracing
  observability = {
    create_log_analytics_workspace = true
    create_application_insights    = true
    application_insights_type      = "web"
  }

  # Environment with Dapr support (enabled by default on ACA environments)
  environment = {}

  # --- Container Apps ---
  container_apps = {

    # Frontend: Public-facing web app
    frontend = {
      revision_mode = "Single"

      template = {
        min_replicas = var.frontend_min_replicas
        max_replicas = var.frontend_max_replicas

        containers = [
          {
            name   = "frontend"
            image  = var.frontend_image
            cpu    = 0.5
            memory = "1Gi"

            env = [
              { name = "BACKEND_URL", value = "http://localhost:3500/v1.0/invoke/backend-api/method" },
            ]
          }
        ]
      }

      ingress = {
        external_enabled = true
        target_port      = var.frontend_port
        transport        = "http"
        traffic_weight = [
          { latest_revision = true, percentage = 100 }
        ]
      }

      dapr = {
        app_id       = "frontend"
        app_port     = var.frontend_port
        app_protocol = "http"
      }
    }

    # Backend API: Internal service accessed via Dapr
    backend-api = {
      revision_mode = "Single"

      template = {
        min_replicas = var.backend_api_min_replicas
        max_replicas = var.backend_api_max_replicas

        containers = [
          {
            name   = "backend-api"
            image  = var.backend_api_image
            cpu    = 1.0
            memory = "2Gi"

            env = [
              { name = "DB_CONNECTION", secret_name = "db-connection-string" },
              { name = "WORKER_APP_ID", value = "worker" },
            ]
          }
        ]
      }

      ingress = {
        external_enabled = false
        target_port      = var.backend_api_port
        transport        = "http"
      }

      dapr = {
        app_id       = "backend-api"
        app_port     = var.backend_api_port
        app_protocol = "http"
      }

      secret = [
        {
          name  = "db-connection-string"
          value = var.db_connection_string
        }
      ]

      identity = {
        type = "SystemAssigned"
      }
    }

    # Worker: Background processor accessed via Dapr pub/sub
    worker = {
      revision_mode = "Single"

      template = {
        min_replicas = var.worker_min_replicas
        max_replicas = var.worker_max_replicas

        containers = [
          {
            name   = "worker"
            image  = var.worker_image
            cpu    = 0.5
            memory = "1Gi"

            env = [
              { name = "DB_CONNECTION", secret_name = "db-connection-string" },
            ]
          }
        ]
      }

      # No external ingress — only accessible via Dapr
      dapr = {
        app_id       = "worker"
        app_port     = var.worker_port
        app_protocol = "http"
      }

      secret = [
        {
          name  = "db-connection-string"
          value = var.db_connection_string
        }
      ]
    }
  }
}
