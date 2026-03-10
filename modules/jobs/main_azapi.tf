# AzAPI overlay for preview features on Container App Jobs.
# These resources are only created when the corresponding feature flag is enabled.

resource "azapi_update_resource" "event_trigger_advanced" {
  count = var.feature_flags.event_trigger_advanced && lookup(var.provider_overrides, "event_trigger_advanced", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/jobs@2024-10-02-preview"
  resource_id = azurerm_container_app_job.this.id

  body = {
    properties = {
      configuration = {
        triggerType = "Event"
        eventTriggerConfig = {
          replicaCompletionCount = try(var.event_trigger_config.replica_completion_count, 1)
          parallelism            = try(var.event_trigger_config.parallelism, 1)
          scale = {
            maxExecutions            = try(var.event_trigger_config.scale.max_executions, 10)
            minExecutions            = try(var.event_trigger_config.scale.min_executions, 0)
            pollingIntervalInSeconds = try(var.event_trigger_config.scale.polling_interval_in_seconds, 30)
          }
        }
      }
    }
  }
}
