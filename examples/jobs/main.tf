# Jobs Example — Terraform ACA Extension Layer
#
# Demonstrates Container App Jobs with:
# - Scheduled (CRON) job for periodic tasks
# - Event-driven job triggered by Azure Storage Queue
# - Different trigger configurations

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
# ACA Module — Jobs
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = {
    Pattern   = "Jobs"
    ManagedBy = "Terraform"
  }

  # Observability
  observability = {
    create_log_analytics_workspace = true
  }

  # Environment (default settings)
  environment = {}

  # No container apps — jobs only
  container_apps = {}

  # --- Jobs ---
  jobs = {

    # Scheduled job: runs every hour to clean up expired data
    cleanup = {
      replica_timeout_in_seconds = var.cleanup_timeout_seconds

      template = {
        containers = [
          {
            name   = "cleanup"
            image  = var.cleanup_job_image
            cpu    = 0.5
            memory = "1Gi"

            env = [
              { name = "DB_CONNECTION", secret_name = "db-connection-string" },
              { name = "RETENTION_DAYS", value = "30" },
            ]
          }
        ]
      }

      schedule_trigger_config = {
        cron_expression          = var.cleanup_cron_expression
        parallelism              = 1
        replica_completion_count = 1
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

    # Event-driven job: processes messages from Azure Storage Queue
    queue-processor = {
      replica_timeout_in_seconds = var.queue_timeout_seconds
      replica_retry_limit        = var.queue_replica_retry_limit

      template = {
        containers = [
          {
            name   = "processor"
            image  = var.queue_processor_image
            cpu    = 1.0
            memory = "2Gi"

            env = [
              { name = "QUEUE_CONNECTION", secret_name = "queue-connection-string" },
              { name = "QUEUE_NAME", value = var.queue_name },
            ]
          }
        ]
      }

      event_trigger_config = {
        parallelism              = 5
        replica_completion_count = 1
        scale = {
          min_executions           = 0
          max_executions           = 50
          polling_interval_seconds = 30
          rules = [
            {
              name             = "azure-queue"
              type             = "azure-queue"
              custom_rule_type = "azure-queue"
              metadata = {
                queueName   = var.queue_name
                queueLength = "10"
                accountName = var.storage_account_name
              }
              authentication = [
                {
                  trigger_parameter = "connection"
                  secret_name       = "queue-connection-string"
                }
              ]
            }
          ]
        }
      }

      secret = [
        {
          name  = "queue-connection-string"
          value = var.queue_connection_string
        }
      ]

      identity = {
        type = "SystemAssigned"
      }
    }
  }
}
