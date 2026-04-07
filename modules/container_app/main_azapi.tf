# ---------------------------------------------------------------------------
# AzAPI overlay resources – conditional on feature_flags
# ---------------------------------------------------------------------------

# --- advanced_ingress: additional port mappings (preview) ---
resource "azapi_update_resource" "advanced_ingress" {
  count = var.feature_flags.advanced_ingress && lookup(var.provider_overrides, "advanced_ingress", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/containerApps@2024-10-02-preview"
  resource_id = azurerm_container_app.this.id

  body = {
    properties = {
      configuration = {
        ingress = {
          additionalPortMappings = [
            for pm in var.additional_port_mappings : {
              external    = pm.external
              targetPort  = pm.target_port
              exposedPort = pm.exposed_port
            }
          ]
        }
      }
    }
  }
}

# --- kind_functionapp: set resource kind to "functionapp" ---
resource "azapi_update_resource" "kind_functionapp" {
  count = var.feature_flags.kind_functionapp && lookup(var.provider_overrides, "kind_functionapp", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.this.id

  body = {
    kind = "functionapp"
  }
}

# --- dapr_app_health: Dapr application health checks (preview) ---
resource "azapi_update_resource" "dapr_app_health" {
  count = var.feature_flags.dapr_app_health && lookup(var.provider_overrides, "dapr_app_health", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/containerApps@2024-10-02-preview"
  resource_id = azurerm_container_app.this.id

  body = {
    properties = {
      configuration = {
        dapr = {
          appHealth = {
            enabled              = true
            path                 = try(var.dapr.app_health_path, "/health")
            probeIntervalSeconds = try(var.dapr.app_health_probe_interval, 10)
            probeTimeoutMs       = try(var.dapr.app_health_probe_timeout, 2000)
            threshold            = try(var.dapr.app_health_threshold, 3)
          }
        }
      }
    }
  }
}

# --- sticky_sessions: session affinity (GA in API since 2023-05, not in azurerm) ---
resource "azapi_update_resource" "sticky_sessions" {
  count = var.feature_flags.sticky_sessions && lookup(var.provider_overrides, "sticky_sessions", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.this.id

  body = {
    properties = {
      configuration = {
        ingress = {
          stickySessions = {
            affinity = var.sticky_sessions_affinity
          }
        }
      }
    }
  }
}
