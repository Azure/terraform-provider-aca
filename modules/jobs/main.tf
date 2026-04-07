resource "azurerm_container_app_job" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.container_app_environment_id
  replica_timeout_in_seconds   = var.replica_timeout_in_seconds
  replica_retry_limit          = var.replica_retry_limit
  workload_profile_name        = var.workload_profile_name
  tags                         = var.tags

  template {
    dynamic "container" {
      for_each = try(var.template.containers, [])
      content {
        name   = container.value.name
        image  = container.value.image
        cpu    = container.value.cpu
        memory = container.value.memory

        dynamic "env" {
          for_each = try(container.value.env, [])
          content {
            name        = env.value.name
            value       = try(env.value.value, null)
            secret_name = try(env.value.secret_name, null)
          }
        }

        dynamic "volume_mounts" {
          for_each = try(container.value.volume_mounts, [])
          content {
            name = volume_mounts.value.name
            path = volume_mounts.value.path
          }
        }
      }
    }

    dynamic "init_container" {
      for_each = try(var.template.init_containers, [])
      content {
        name   = init_container.value.name
        image  = init_container.value.image
        cpu    = try(init_container.value.cpu, null)
        memory = try(init_container.value.memory, null)

        dynamic "env" {
          for_each = try(init_container.value.env, [])
          content {
            name        = env.value.name
            value       = try(env.value.value, null)
            secret_name = try(env.value.secret_name, null)
          }
        }
      }
    }

    dynamic "volume" {
      for_each = try(var.template.volumes, [])
      content {
        name         = volume.value.name
        storage_type = try(volume.value.storage_type, null)
        storage_name = try(volume.value.storage_name, null)
      }
    }
  }

  dynamic "schedule_trigger_config" {
    for_each = var.schedule_trigger_config != null ? [var.schedule_trigger_config] : []
    content {
      cron_expression          = schedule_trigger_config.value.cron_expression
      parallelism              = try(schedule_trigger_config.value.parallelism, null)
      replica_completion_count = try(schedule_trigger_config.value.replica_completion_count, null)
    }
  }

  dynamic "event_trigger_config" {
    for_each = var.event_trigger_config != null ? [var.event_trigger_config] : []
    content {
      parallelism              = try(event_trigger_config.value.parallelism, null)
      replica_completion_count = try(event_trigger_config.value.replica_completion_count, null)

      dynamic "scale" {
        for_each = try(event_trigger_config.value.scale, null) != null ? [event_trigger_config.value.scale] : []
        content {
          max_executions              = try(scale.value.max_executions, null)
          min_executions              = try(scale.value.min_executions, null)
          polling_interval_in_seconds = try(scale.value.polling_interval_in_seconds, null)

          dynamic "rules" {
            for_each = try(scale.value.rules, [])
            content {
              name             = rules.value.name
              metadata         = try(rules.value.metadata, null)
              custom_rule_type = try(rules.value.custom_rule_type, null)

              dynamic "authentication" {
                for_each = try(rules.value.authentication, [])
                content {
                  trigger_parameter = authentication.value.trigger_parameter
                  secret_name       = authentication.value.secret_name
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "manual_trigger_config" {
    for_each = var.manual_trigger_config != null ? [var.manual_trigger_config] : []
    content {
      parallelism              = try(manual_trigger_config.value.parallelism, null)
      replica_completion_count = try(manual_trigger_config.value.replica_completion_count, null)
    }
  }

  dynamic "registry" {
    for_each = var.registry
    content {
      server               = registry.value.server
      username             = try(registry.value.username, null)
      password_secret_name = try(registry.value.password_secret_name, null)
      identity             = try(registry.value.identity, null)
    }
  }

  dynamic "secret" {
    for_each = var.secret
    content {
      name                = secret.value.name
      value               = try(secret.value.value, null)
      key_vault_secret_id = try(secret.value.key_vault_secret_id, null)
      identity            = try(secret.value.identity, null)
    }
  }

  dynamic "identity" {
    for_each = var.identity != null ? [var.identity] : []
    content {
      type         = identity.value.type
      identity_ids = try(identity.value.identity_ids, null)
    }
  }

  lifecycle {
    precondition {
      condition     = length([for v in [var.schedule_trigger_config, var.event_trigger_config, var.manual_trigger_config] : v if v != null]) == 1
      error_message = "Exactly one of schedule_trigger_config, event_trigger_config, or manual_trigger_config must be provided."
    }
  }
}
