# ---------------------------------------------------------------------------
# AzAPI overlay resources for preview features
# ---------------------------------------------------------------------------

resource "azapi_update_resource" "peer_authentication" {
  count = (
    !local.is_express &&
    var.feature_flags.peer_authentication &&
    lookup(var.provider_overrides, "peer_authentication", "azapi") == "azapi"
  ) ? 1 : 0

  type        = "Microsoft.App/managedEnvironments@2024-10-02-preview"
  resource_id = local.environment_id

  body = {
    properties = {
      peerAuthentication = {
        mtls = {
          enabled = true
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Premium Ingress — dedicated workload profile for ingress proxies
# ---------------------------------------------------------------------------

resource "azapi_update_resource" "ingress_configuration" {
  count = (
    !local.is_express &&
    var.feature_flags.premium_ingress &&
    var.ingress_configuration != null &&
    lookup(var.provider_overrides, "premium_ingress", "azapi") == "azapi"
  ) ? 1 : 0

  type        = "Microsoft.App/managedEnvironments@2025-07-01"
  resource_id = local.environment_id

  body = {
    properties = {
      ingressConfiguration = merge(
        {
          workloadProfileName = var.ingress_configuration.workload_profile_name
        },
        var.ingress_configuration.termination_grace_period_minutes != null ? {
          terminationGracePeriodSeconds = var.ingress_configuration.termination_grace_period_minutes * 60
        } : {},
        var.ingress_configuration.request_idle_timeout != null ? {
          requestIdleTimeout = var.ingress_configuration.request_idle_timeout
        } : {},
        var.ingress_configuration.header_count_limit != null ? {
          headerCountLimit = var.ingress_configuration.header_count_limit
        } : {}
      )
    }
  }

  depends_on = [
    azurerm_container_app_environment.this,
    azapi_resource.express,
  ]
}
