# Observability Module

Creates observability resources for Azure Container Apps (ACA), including a Log Analytics workspace, Application Insights, and diagnostic settings.

## Resources Created

- **Log Analytics Workspace** — Central log collection and querying (optional, can use an existing workspace)
- **Application Insights** — Application performance monitoring (optional)
- **Diagnostic Settings** — Routes platform logs and metrics from ACA resources to Log Analytics

## Usage

```hcl
module "observability" {
  source = "./modules/observability"

  name_prefix         = "myapp"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  create_application_insights = true

  diagnostic_settings = [
    {
      name               = "aca-diagnostics"
      target_resource_id = azurerm_container_app_environment.example.id
      log_categories     = ["ContainerAppConsoleLogs", "ContainerAppSystemLogs"]
      metric_categories  = ["AllMetrics"]
    }
  ]

  tags = {
    Environment = "dev"
  }
}
```
