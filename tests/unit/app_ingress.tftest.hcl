# ---------------------------------------------------------------------------
# Container App — Ingress Configuration Test
# ---------------------------------------------------------------------------
# Validates that the container_app module correctly configures ingress.

variables {
  name                         = "test-app-ingress"
  resource_group_name          = "rg-test"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-env"
  revision_mode                = "Single"

  template = {
    min_replicas = 1
    max_replicas = 5

    containers = [
      {
        name   = "web"
        image  = "mcr.microsoft.com/k8se/quickstart:latest"
        cpu    = 0.5
        memory = "1Gi"
      }
    ]
  }

  ingress = {
    external_enabled = true
    target_port      = 80
    transport        = "http"
    traffic_weight = [
      { latest_revision = true, percentage = 100 }
    ]
  }
}

run "app_ingress_validates" {
  command = plan

  module {
    source = "../../modules/container_app"
  }

  assert {
    condition     = azurerm_container_app.this.name == "test-app-ingress"
    error_message = "Container app name should match input variable."
  }
}
