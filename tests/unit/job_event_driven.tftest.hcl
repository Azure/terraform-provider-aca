# ---------------------------------------------------------------------------
# Job — Event-Driven Configuration Test
# ---------------------------------------------------------------------------
# Validates that the jobs module accepts valid input for an event-driven job.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  name                         = "test-job-event"
  resource_group_name          = "rg-test"
  location                     = "eastus"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-env"
  replica_timeout_in_seconds   = 600
  replica_retry_limit          = 3

  template = {
    containers = [
      {
        name   = "processor"
        image  = "mcr.microsoft.com/k8se/quickstart:latest"
        cpu    = 0.5
        memory = "1Gi"
      }
    ]
  }

  event_trigger_config = {
    parallelism              = 5
    replica_completion_count = 1
    scale = {
      min_executions           = 0
      max_executions           = 20
      polling_interval_seconds = 30
      rules = [
        {
          name             = "queue-trigger"
          type             = "azure-queue"
          custom_rule_type = "azure-queue"
          metadata = {
            queueName   = "work-items"
            queueLength = "5"
          }
          authentication = [
            {
              trigger_parameter = "connection"
              secret_name       = "queue-conn"
            }
          ]
        }
      ]
    }
  }

  secret = [
    {
      name  = "queue-conn"
      value = "DefaultEndpointsProtocol=https;AccountName=test"
    }
  ]
}

run "job_event_driven_validates" {
  command = plan

  module {
    source = "./modules/jobs"
  }

  assert {
    condition     = azurerm_container_app_job.this.name == "test-job-event"
    error_message = "Job name should match input variable."
  }

  assert {
    condition     = azurerm_container_app_job.this.replica_retry_limit == 3
    error_message = "Replica retry limit should be 3."
  }
}
