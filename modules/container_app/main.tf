locals {
  is_express = var.environment_mode == "Express"
}

resource "azurerm_container_app" "this" {
  count = local.is_express ? 0 : 1

  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = var.revision_mode
  workload_profile_name        = var.workload_profile_name
  tags                         = var.tags

  # ---------------------------------------------------------------------------
  # template
  # ---------------------------------------------------------------------------
  template {
    min_replicas    = try(var.template.min_replicas, null)
    max_replicas    = try(var.template.max_replicas, null)
    revision_suffix = try(var.template.revision_suffix, null)

    dynamic "container" {
      for_each = var.template.containers
      content {
        name              = container.value.name
        image             = container.value.image
        cpu               = container.value.cpu
        memory            = container.value.memory
        command           = try(container.value.command, null)
        args              = try(container.value.args, null)
        ephemeral_storage = try(container.value.ephemeral_storage, null)

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

        dynamic "liveness_probe" {
          for_each = try(container.value.liveness_probe, null) != null ? [container.value.liveness_probe] : []
          content {
            port                    = liveness_probe.value.port
            transport               = liveness_probe.value.transport
            path                    = try(liveness_probe.value.path, null)
            initial_delay           = try(liveness_probe.value.initial_delay, null)
            interval_seconds        = try(liveness_probe.value.interval_seconds, null)
            timeout                 = try(liveness_probe.value.timeout, null)
            failure_count_threshold = try(liveness_probe.value.failure_count_threshold, null)
            host                    = try(liveness_probe.value.host, null)

            dynamic "header" {
              for_each = try(liveness_probe.value.header, [])
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
          }
        }

        dynamic "readiness_probe" {
          for_each = try(container.value.readiness_probe, null) != null ? [container.value.readiness_probe] : []
          content {
            port                    = readiness_probe.value.port
            transport               = readiness_probe.value.transport
            path                    = try(readiness_probe.value.path, null)
            interval_seconds        = try(readiness_probe.value.interval_seconds, null)
            timeout                 = try(readiness_probe.value.timeout, null)
            failure_count_threshold = try(readiness_probe.value.failure_count_threshold, null)
            success_count_threshold = try(readiness_probe.value.success_count_threshold, null)
            host                    = try(readiness_probe.value.host, null)

            dynamic "header" {
              for_each = try(readiness_probe.value.header, [])
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
          }
        }

        dynamic "startup_probe" {
          for_each = try(container.value.startup_probe, null) != null ? [container.value.startup_probe] : []
          content {
            port                    = startup_probe.value.port
            transport               = startup_probe.value.transport
            path                    = try(startup_probe.value.path, null)
            interval_seconds        = try(startup_probe.value.interval_seconds, null)
            timeout                 = try(startup_probe.value.timeout, null)
            failure_count_threshold = try(startup_probe.value.failure_count_threshold, null)
            host                    = try(startup_probe.value.host, null)

            dynamic "header" {
              for_each = try(startup_probe.value.header, [])
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
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

        dynamic "volume_mounts" {
          for_each = try(init_container.value.volume_mounts, [])
          content {
            name = volume_mounts.value.name
            path = volume_mounts.value.path
          }
        }
      }
    }

    dynamic "volume" {
      for_each = try(var.template.volumes, [])
      content {
        name         = volume.value.name
        storage_name = try(volume.value.storage_name, null)
        storage_type = try(volume.value.storage_type, null)
      }
    }

    dynamic "http_scale_rule" {
      for_each = try(var.template.http_scale_rules, [])
      content {
        name                = http_scale_rule.value.name
        concurrent_requests = http_scale_rule.value.concurrent_requests
      }
    }

    dynamic "custom_scale_rule" {
      for_each = try(var.template.custom_scale_rules, [])
      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = custom_scale_rule.value.custom_rule_type
        metadata         = custom_scale_rule.value.metadata
        identity_id      = try(custom_scale_rule.value.identity_id, null)
      }
    }
  }

  # ---------------------------------------------------------------------------
  # ingress
  # ---------------------------------------------------------------------------
  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      target_port                = ingress.value.target_port
      external_enabled           = try(ingress.value.external_enabled, false)
      transport                  = try(ingress.value.transport, "auto")
      exposed_port               = try(ingress.value.exposed_port, null)
      allow_insecure_connections = try(ingress.value.allow_insecure_connections, false)

      dynamic "cors" {
        for_each = try(ingress.value.cors, null) != null ? [ingress.value.cors] : []
        content {
          allow_credentials_enabled = try(cors.value.allow_credentials_enabled, false)
          allowed_headers           = try(cors.value.allowed_headers, null)
          allowed_methods           = try(cors.value.allowed_methods, null)
          allowed_origins           = cors.value.allowed_origins
          exposed_headers           = try(cors.value.exposed_headers, null)
          max_age_in_seconds        = try(cors.value.max_age_in_seconds, null)
        }
      }

      dynamic "ip_security_restriction" {
        for_each = try(ingress.value.ip_security_restrictions, [])
        content {
          action           = ip_security_restriction.value.action
          description      = try(ip_security_restriction.value.description, null)
          ip_address_range = ip_security_restriction.value.ip_address_range
          name             = ip_security_restriction.value.name
        }
      }

      dynamic "traffic_weight" {
        for_each = length(try(ingress.value.traffic_weight, [])) > 0 ? ingress.value.traffic_weight : [{ percentage = 100, latest_revision = true }]
        content {
          percentage      = traffic_weight.value.percentage
          label           = try(traffic_weight.value.label, null)
          latest_revision = try(traffic_weight.value.latest_revision, null)
          revision_suffix = try(traffic_weight.value.revision_suffix, null)
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # dapr
  # ---------------------------------------------------------------------------
  dynamic "dapr" {
    for_each = var.dapr != null ? [var.dapr] : []
    content {
      app_id       = dapr.value.app_id
      app_port     = try(dapr.value.app_port, null)
      app_protocol = try(dapr.value.app_protocol, null)
    }
  }

  # ---------------------------------------------------------------------------
  # identity
  # ---------------------------------------------------------------------------
  dynamic "identity" {
    for_each = var.identity != null ? [var.identity] : []
    content {
      type         = identity.value.type
      identity_ids = try(identity.value.identity_ids, null)
    }
  }

  # ---------------------------------------------------------------------------
  # registry
  # ---------------------------------------------------------------------------
  dynamic "registry" {
    for_each = var.registry
    content {
      server               = registry.value.server
      username             = try(registry.value.username, null)
      password_secret_name = try(registry.value.password_secret_name, null)
      identity             = try(registry.value.identity, null)
    }
  }

  # ---------------------------------------------------------------------------
  # secret
  # ---------------------------------------------------------------------------
  dynamic "secret" {
    for_each = var.secret
    content {
      name                = secret.value.name
      value               = try(secret.value.value, null)
      identity            = try(secret.value.identity, null)
      key_vault_secret_id = try(secret.value.key_vault_secret_id, null)
    }
  }
}
