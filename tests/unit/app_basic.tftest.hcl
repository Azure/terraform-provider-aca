# ---------------------------------------------------------------------------
# Container App — Basic Configuration Test
# ---------------------------------------------------------------------------
# Validates that the container_app module accepts valid input for a minimal app.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  name                         = "test-app"
  resource_group_name          = "rg-test"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-env"
  revision_mode                = "Single"

  template = {
    min_replicas = 0
    max_replicas = 3

    containers = [
      {
        name   = "app"
        image  = "mcr.microsoft.com/k8se/quickstart:latest"
        cpu    = 0.25
        memory = "0.5Gi"
      }
    ]
  }
}

run "app_basic_validates" {
  command = plan

  module {
    source = "./modules/container_app"
  }

  assert {
    condition     = azurerm_container_app.this[0].name == "test-app"
    error_message = "Container app name should match input variable."
  }

  assert {
    condition     = azurerm_container_app.this[0].revision_mode == "Single"
    error_message = "Revision mode should be Single."
  }
}
