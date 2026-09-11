# ---------------------------------------------------------------------------
# Container App — Preview Feature (AzAPI Overlay) Test
# ---------------------------------------------------------------------------
# Validates that enabling a feature flag creates the AzAPI overlay resource.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  name                         = "test-app-preview"
  resource_group_name          = "rg-test"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-env"
  revision_mode                = "Single"

  template = {
    min_replicas = 0
    max_replicas = 1

    containers = [
      {
        name   = "app"
        image  = "mcr.microsoft.com/k8se/quickstart:latest"
        cpu    = 0.25
        memory = "0.5Gi"
      }
    ]
  }

  feature_flags = {
    advanced_ingress = true
  }

  additional_port_mappings = [
    {
      external     = false
      target_port  = 8443
      exposed_port = 8443
    }
  ]
}

run "app_preview_feature_creates_overlay" {
  command = plan

  module {
    source = "./modules/container_app"
  }

  assert {
    condition     = length(azapi_update_resource.advanced_ingress) == 1
    error_message = "Enabling advanced_ingress feature flag should create an AzAPI overlay resource."
  }
}

# Test that overlay is NOT created when feature flag is disabled
run "app_preview_feature_disabled_no_overlay" {
  command = plan

  variables {
    feature_flags = {
      advanced_ingress = false
    }
    additional_port_mappings = []
  }

  module {
    source = "./modules/container_app"
  }

  assert {
    condition     = length(azapi_update_resource.advanced_ingress) == 0
    error_message = "Disabling advanced_ingress feature flag should not create an AzAPI overlay resource."
  }
}
