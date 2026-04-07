# ---------------------------------------------------------------------------
# Job — Scheduled (CRON) Configuration Test
# ---------------------------------------------------------------------------
# Validates that the jobs module accepts valid input for a scheduled job.

variables {
  name                         = "test-job-scheduled"
  resource_group_name          = "rg-test"
  location                     = "eastus"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-env"
  replica_timeout_in_seconds   = 300

  template = {
    containers = [
      {
        name   = "cleanup"
        image  = "mcr.microsoft.com/k8se/quickstart:latest"
        cpu    = 0.25
        memory = "0.5Gi"
      }
    ]
  }

  schedule_trigger_config = {
    cron_expression          = "0 */6 * * *"
    parallelism              = 1
    replica_completion_count = 1
  }
}

run "job_scheduled_validates" {
  command = plan

  module {
    source = "../../modules/jobs"
  }

  assert {
    condition     = azurerm_container_app_job.this.name == "test-job-scheduled"
    error_message = "Job name should match input variable."
  }

  assert {
    condition     = azurerm_container_app_job.this.replica_timeout_in_seconds == 300
    error_message = "Replica timeout should be 300 seconds."
  }
}
