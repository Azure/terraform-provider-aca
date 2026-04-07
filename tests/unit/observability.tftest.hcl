# ---------------------------------------------------------------------------
# Observability Module Test
# ---------------------------------------------------------------------------
# Validates that the observability module creates Log Analytics and
# Application Insights resources.

variables {
  name_prefix         = "test-obs"
  resource_group_name = "rg-test"
  location            = "eastus"

  create_log_analytics_workspace      = true
  existing_log_analytics_workspace_id = null
  log_analytics_sku                   = "PerGB2018"
  log_analytics_retention_in_days     = 30
  create_application_insights         = true
  application_insights_type           = "web"
  diagnostic_settings                 = []
  tags                                = { Environment = "test" }
}

run "observability_creates_workspace" {
  command = plan

  module {
    source = "../../modules/observability"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this[0].name == "test-obs-law"
    error_message = "Log Analytics workspace name should follow naming convention."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this[0].retention_in_days == 30
    error_message = "Retention should be 30 days."
  }
}

run "observability_creates_app_insights" {
  command = plan

  module {
    source = "../../modules/observability"
  }

  assert {
    condition     = azurerm_application_insights.this[0].name == "test-obs-ai"
    error_message = "Application Insights name should follow naming convention."
  }

  assert {
    condition     = azurerm_application_insights.this[0].application_type == "web"
    error_message = "Application type should be web."
  }
}
