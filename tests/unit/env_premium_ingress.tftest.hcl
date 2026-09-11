# ---------------------------------------------------------------------------
# Environment — Premium Ingress Configuration Test
# ---------------------------------------------------------------------------
# Validates that the container_app_environment module correctly merges the
# dedicated ingress workload profile and plans the AzAPI overlay.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  name                = "test-env-premium-ingress"
  resource_group_name = "rg-test"
  location            = "eastus"

  feature_flags = {
    premium_ingress = true
  }

  ingress_configuration = {
    workload_profile_name            = "my-ingress"
    workload_profile_type            = "D8"
    minimum_node_count               = 3
    maximum_node_count               = 15
    termination_grace_period_minutes = 2
    request_idle_timeout             = 6
    header_count_limit               = 200
  }
}

run "premium_ingress_validates" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  assert {
    condition     = azurerm_container_app_environment.this[0].name == "test-env-premium-ingress"
    error_message = "Environment name should match input variable."
  }

  # The dedicated ingress workload profile should be merged into the list
  assert {
    condition     = length(azurerm_container_app_environment.this[0].workload_profile) == 1
    error_message = "Should have exactly one workload profile (the ingress profile)."
  }

  # AzAPI overlay should be planned
  assert {
    condition     = length(azapi_update_resource.ingress_configuration) == 1
    error_message = "Should plan one azapi_update_resource for ingress_configuration."
  }
}

# ---------------------------------------------------------------------------
# Premium Ingress with user-defined workload profiles
# ---------------------------------------------------------------------------

run "premium_ingress_with_user_profiles" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  variables {
    workload_profile = [
      {
        name                  = "app-compute"
        workload_profile_type = "D4"
        minimum_count         = 1
        maximum_count         = 3
      }
    ]
  }

  assert {
    condition     = length(azurerm_container_app_environment.this[0].workload_profile) == 2
    error_message = "Should have two workload profiles (user + ingress)."
  }
}

# ---------------------------------------------------------------------------
# Defaults — Premium Ingress with all defaults
# ---------------------------------------------------------------------------

run "premium_ingress_defaults" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  variables {
    ingress_configuration = {}
  }

  assert {
    condition     = length(azurerm_container_app_environment.this[0].workload_profile) == 1
    error_message = "Should have exactly one workload profile (the default ingress profile)."
  }
}
