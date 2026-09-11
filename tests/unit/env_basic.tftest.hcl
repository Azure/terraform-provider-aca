# ---------------------------------------------------------------------------
# Environment — Basic Configuration Test
# ---------------------------------------------------------------------------
# Validates that the container_app_environment module accepts valid input
# and produces expected plan output.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  name                = "test-env"
  resource_group_name = "rg-test"
  location            = "eastus"
}

run "env_basic_validates" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  assert {
    condition     = azurerm_container_app_environment.this[0].name == "test-env"
    error_message = "Environment name should match input variable."
  }

  assert {
    condition     = azurerm_container_app_environment.this[0].resource_group_name == "rg-test"
    error_message = "Resource group name should match input variable."
  }

  assert {
    condition     = azurerm_container_app_environment.this[0].location == "eastus"
    error_message = "Location should match input variable."
  }
}
