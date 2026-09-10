data "azurerm_client_config" "current" {}

locals {
  express_identity = var.identity == null ? {} : {
    identity = {
      type = var.identity.type
      userAssignedIdentities = {
        for identity_id in coalesce(var.identity.identity_ids, []) : identity_id => {}
      }
    }
  }

  express_ingress = var.ingress == null ? {} : {
    ingress = merge(
      {
        external   = var.ingress.external_enabled
        targetPort = var.ingress.target_port
        transport  = "Http"
      },
      length(var.ingress.ip_security_restrictions) > 0 ? {
        ipSecurityRestrictions = [
          for rule in var.ingress.ip_security_restrictions : merge(
            {
              action         = rule.action
              ipAddressRange = rule.ip_address_range
              name           = rule.name
            },
            rule.description == null ? {} : { description = rule.description }
          )
        ]
      } : {},
      var.ingress.cors == null ? {} : {
        corsPolicy = merge(
          {
            allowedOrigins = var.ingress.cors.allowed_origins
          },
          var.ingress.cors.allowed_headers == null ? {} : { allowedHeaders = var.ingress.cors.allowed_headers },
          var.ingress.cors.allowed_methods == null ? {} : { allowedMethods = var.ingress.cors.allowed_methods },
          var.ingress.cors.max_age_in_seconds == null ? {} : { maxAge = var.ingress.cors.max_age_in_seconds },
          { allowCredentials = var.ingress.cors.allow_credentials_enabled }
        )
      }
    )
  }

  express_registries = length(var.registry) == 0 ? {} : {
    registries = [
      for registry in var.registry : merge(
        { server = registry.server },
        try(registry.username, null) == null ? {} : { username = registry.username },
        try(registry.password_secret_name, null) == null ? {} : { passwordSecretRef = registry.password_secret_name },
        try(registry.identity, null) == null ? {} : { identity = registry.identity }
      )
    ]
  }

  express_secrets = length(var.secret) == 0 ? {} : {
    secrets = [
      for secret in var.secret : merge(
        { name = secret.name },
        try(secret.value, null) == null ? {} : { value = secret.value }
      )
    ]
  }

  express_containers = [
    for container in var.template.containers : merge(
      {
        name  = container.name
        image = container.image
        resources = merge(
          {
            cpu    = container.cpu
            memory = container.memory
          },
          container.ephemeral_storage == null ? {} : { ephemeralStorage = container.ephemeral_storage }
        )
      },
      container.command == null ? {} : { command = container.command },
      container.args == null ? {} : { args = container.args },
      length(container.env) == 0 ? {} : {
        env = [
          for env in container.env : merge(
            { name = env.name },
            env.value == null ? {} : { value = env.value },
            env.secret_name == null ? {} : { secretRef = env.secret_name }
          )
        ]
      },
      length(compact([
        container.liveness_probe == null ? null : "liveness",
        container.readiness_probe == null ? null : "readiness",
        container.startup_probe == null ? null : "startup",
        ])) == 0 ? {} : {
        probes = concat(
          container.liveness_probe == null ? [] : [merge(
            {
              type                = "Liveness"
              failureThreshold    = try(container.liveness_probe.failure_count_threshold, null)
              initialDelaySeconds = try(container.liveness_probe.initial_delay, null)
              periodSeconds       = try(container.liveness_probe.interval_seconds, null)
              timeoutSeconds      = try(container.liveness_probe.timeout, null)
              successThreshold    = 1
            },
            jsondecode(lower(container.liveness_probe.transport) == "tcp" ? jsonencode({
              tcpSocket = {
                host = try(container.liveness_probe.host, null)
                port = container.liveness_probe.port
              }
              }) : jsonencode({
              httpGet = {
                host = try(container.liveness_probe.host, null)
                path = try(container.liveness_probe.path, "/")
                port = container.liveness_probe.port
                httpHeaders = [
                  for header in try(container.liveness_probe.header, []) : {
                    name  = header.name
                    value = header.value
                  }
                ]
              }
            }))
          )],
          container.readiness_probe == null ? [] : [merge(
            {
              type                = "Readiness"
              failureThreshold    = try(container.readiness_probe.failure_count_threshold, null)
              initialDelaySeconds = try(container.readiness_probe.initial_delay, null)
              periodSeconds       = try(container.readiness_probe.interval_seconds, null)
              timeoutSeconds      = try(container.readiness_probe.timeout, null)
              successThreshold    = try(container.readiness_probe.success_count_threshold, null)
            },
            jsondecode(lower(container.readiness_probe.transport) == "tcp" ? jsonencode({
              tcpSocket = {
                host = try(container.readiness_probe.host, null)
                port = container.readiness_probe.port
              }
              }) : jsonencode({
              httpGet = {
                host = try(container.readiness_probe.host, null)
                path = try(container.readiness_probe.path, "/")
                port = container.readiness_probe.port
                httpHeaders = [
                  for header in try(container.readiness_probe.header, []) : {
                    name  = header.name
                    value = header.value
                  }
                ]
              }
            }))
          )],
          container.startup_probe == null ? [] : [merge(
            {
              type                = "Startup"
              failureThreshold    = try(container.startup_probe.failure_count_threshold, null)
              initialDelaySeconds = try(container.startup_probe.initial_delay, null)
              periodSeconds       = try(container.startup_probe.interval_seconds, null)
              timeoutSeconds      = try(container.startup_probe.timeout, null)
              successThreshold    = 1
            },
            jsondecode(lower(container.startup_probe.transport) == "tcp" ? jsonencode({
              tcpSocket = {
                host = try(container.startup_probe.host, null)
                port = container.startup_probe.port
              }
              }) : jsonencode({
              httpGet = {
                host = try(container.startup_probe.host, null)
                path = try(container.startup_probe.path, "/")
                port = container.startup_probe.port
                httpHeaders = [
                  for header in try(container.startup_probe.header, []) : {
                    name  = header.name
                    value = header.value
                  }
                ]
              }
            }))
          )]
        )
      }
    )
  ]

  express_scale_rules = concat(
    [
      for rule in var.template.http_scale_rules : {
        name = rule.name
        http = {
          metadata = {
            concurrentRequests = tostring(rule.concurrent_requests)
          }
        }
      }
    ],
    [
      for rule in var.template.custom_scale_rules : {
        name = rule.name
        custom = {
          type     = rule.custom_rule_type
          metadata = rule.metadata
        }
      }
    ]
  )
}

resource "azapi_resource" "express" {
  count = local.is_express ? 1 : 0

  type      = "Microsoft.App/containerApps@${var.express_api_version}"
  name      = var.name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  schema_validation_enabled = false
  ignore_null_property      = true
  response_export_values = [
    "properties.latestRevisionFqdn",
    "properties.latestRevisionName",
    "properties.outboundIpAddresses",
    "properties.customDomainVerificationId",
    "properties.provisioningState",
  ]

  body = merge(
    local.express_identity,
    {
      properties = merge(
        {
          environmentId       = var.container_app_environment_id
          workloadProfileName = "Consumption"
          configuration = merge(
            {
              activeRevisionsMode = "Single"
            },
            local.express_ingress,
            local.express_registries,
            local.express_secrets
          )
          template = merge(
            {
              containers = local.express_containers
            },
            try(var.template.min_replicas, null) != null || try(var.template.max_replicas, null) != null || length(local.express_scale_rules) > 0 ? {
              scale = merge(
                try(var.template.min_replicas, null) == null ? {} : { minReplicas = var.template.min_replicas },
                try(var.template.max_replicas, null) == null ? {} : { maxReplicas = var.template.max_replicas },
                length(local.express_scale_rules) == 0 ? {} : { rules = local.express_scale_rules }
              )
            } : {}
          )
        },
        var.outbound_vnet_subnet_id == null ? {} : {
          networking = {
            outboundVnetSubnetId = var.outbound_vnet_subnet_id
          }
        }
      )
    }
  )

  lifecycle {
    precondition {
      condition     = var.location != null
      error_message = "location is required when environment_mode is Express."
    }

    precondition {
      condition     = var.revision_mode == "Single" && try(var.template.revision_suffix, null) == null
      error_message = "Express apps support only Single revision mode and do not support revision_suffix."
    }

    precondition {
      condition     = length(var.template.containers) == 1 && length(var.template.init_containers) == 0
      error_message = "Express apps support exactly one application container and do not support sidecars or init containers."
    }

    precondition {
      condition     = var.dapr == null
      error_message = "Express apps do not support Dapr."
    }

    precondition {
      condition     = length(var.template.volumes) == 0 && alltrue([for container in var.template.containers : length(container.volume_mounts) == 0])
      error_message = "Express apps do not support volumes or volume mounts."
    }

    precondition {
      condition = alltrue([
        for container in var.template.containers :
        container.ephemeral_storage == null ||
        can(regex("^[1-9][0-9]*(Mi|Gi)$", container.ephemeral_storage))
      ])
      error_message = "Express ephemeral_storage must use a positive Mi or Gi value such as 2Gi; the service enforces the 40 GiB replica limit."
    }

    precondition {
      condition     = !var.feature_flags.advanced_ingress && !var.feature_flags.kind_functionapp && !var.feature_flags.dapr_app_health && !var.feature_flags.sticky_sessions
      error_message = "The existing AzAPI overlay feature flags are not supported on Express apps."
    }

    precondition {
      condition     = var.identity == null || (var.identity.type == "UserAssigned" && length(coalesce(var.identity.identity_ids, [])) > 0)
      error_message = "Express app runtime identity supports only UserAssigned identity with at least one identity ID."
    }

    precondition {
      condition = alltrue([
        for secret in var.secret :
        try(secret.key_vault_secret_id, null) == null && try(secret.identity, null) == null
      ])
      error_message = "Express apps support manual secrets but not Key Vault secret references."
    }

    precondition {
      condition     = var.ingress == null || (contains(["auto", "http"], lower(var.ingress.transport)) && !var.ingress.allow_insecure_connections && var.ingress.exposed_port == null)
      error_message = "Express ingress supports HTTP only and does not support insecure HTTP or exposed_port."
    }

    precondition {
      condition     = var.ingress == null || var.ingress.cors == null || var.ingress.cors.exposed_headers == null || length(var.ingress.cors.exposed_headers) == 0
      error_message = "Express CORS does not support exposed response headers."
    }

    precondition {
      condition = alltrue([
        for rule in var.template.custom_scale_rules :
        contains(["cpu", "memory"], lower(rule.custom_rule_type)) && rule.identity_id == null
      ])
      error_message = "Express custom scaling supports unauthenticated CPU and memory rules only."
    }

    precondition {
      condition     = var.outbound_vnet_subnet_id == null || var.environment_infrastructure_subnet_id == null
      error_message = "Express app-level outbound_vnet_subnet_id is mutually exclusive with environment-level VNet integration."
    }
  }
}

locals {
  app_id = local.is_express ? azapi_resource.express[0].id : azurerm_container_app.this[0].id
}
