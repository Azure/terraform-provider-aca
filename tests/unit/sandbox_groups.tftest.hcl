mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azapi" {}

variables {
  name              = "sandbox1"
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  location          = "swedencentral"
}

run "stable_profile_is_narrow" {
  command = plan

  module {
    source = "./modules/sandbox_groups"
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.App/sandboxGroups@2026-02-01-preview"
    error_message = "Stable-profile Sandbox Groups must default to the currently deployed 2026-02-01-preview contract."
  }

  assert {
    condition     = length(keys(azapi_resource.this.body.properties)) == 0
    error_message = "The stable profile must omit preview-only defaults."
  }
}

run "stable_profile_supports_environment_override" {
  command = plan

  module {
    source = "./modules/sandbox_groups"
  }

  variables {
    api_version    = "2026-07-01"
    environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/env"
  }

  assert {
    condition     = azapi_resource.this.body.properties.environmentId != null
    error_message = "The stable profile must serialize an environment link when a supporting API override is explicit."
  }
}

run "rich_preview_serializes_defaults_and_identity" {
  command = plan

  module {
    source = "./modules/sandbox_groups"
  }

  variables {
    api_profile             = "rich_preview"
    default_cpu             = "2"
    default_memory          = "4Gi"
    default_disk            = "32Gi"
    max_sandbox_count       = 10
    default_timeout_seconds = 3600
    identity = {
      type = "SystemAssigned"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.App/sandboxGroups@2026-02-01-preview"
    error_message = "Rich-preview Sandbox Groups must use 2026-02-01-preview."
  }

  assert {
    condition     = azapi_resource.this.body.properties.defaultCpu == "2"
    error_message = "Rich-preview Sandbox Group defaults must be serialized."
  }

  assert {
    condition     = azapi_resource.this.identity[0].type == "SystemAssigned"
    error_message = "Rich-preview identity must use the native AzAPI identity block."
  }
}
