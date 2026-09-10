mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azapi" {}

variables {
  name                = "test-express"
  resource_group_name = "rg-test"
  location            = "swedencentral"
  environment_mode    = "Express"
}

run "express_environment_uses_azapi" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  assert {
    condition     = length(azurerm_container_app_environment.this) == 0
    error_message = "Express must not create an AzureRM managed environment."
  }

  assert {
    condition     = azapi_resource.express[0].type == "Microsoft.App/managedEnvironments@2026-03-02-preview"
    error_message = "Express must default to the currently deployed 2026-03-02-preview ARM contract."
  }

  assert {
    condition     = azapi_resource.express[0].body.properties.environmentMode == "Express"
    error_message = "Express environment body must set environmentMode."
  }

  assert {
    condition     = azapi_resource.express[0].ignore_null_property
    error_message = "Express environment requests must omit null properties."
  }
}

run "express_feature_flag_alias" {
  command = plan

  module {
    source = "./modules/container_app_environment"
  }

  variables {
    environment_mode = null
    feature_flags = {
      express_mode = true
    }
  }

  assert {
    condition     = azapi_resource.express[0].body.properties.environmentMode == "Express"
    error_message = "The legacy express_mode feature flag must remain a compatibility alias."
  }
}

run "express_app_serializes_supported_features" {
  command = plan

  module {
    source = "./modules/container_app"
  }

  variables {
    name                         = "test-express-app"
    location                     = "swedencentral"
    resource_group_name          = "rg-test"
    container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test-express"
    environment_mode             = "Express"
    revision_mode                = "Single"

    template = {
      containers = [{
        name              = "app"
        image             = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
        cpu               = 0.25
        memory            = "0.5Gi"
        ephemeral_storage = "2Gi"
        liveness_probe = {
          transport = "HTTP"
          port      = 80
          path      = "/"
        }
      }]
      min_replicas = 0
      max_replicas = 2
      http_scale_rules = [{
        name                = "http"
        concurrent_requests = 50
      }]
    }

    ingress = {
      external_enabled = true
      target_port      = 80
      transport        = "http"
      cors = {
        allowed_origins = ["https://example.com"]
      }
      ip_security_restrictions = [{
        name             = "internet"
        action           = "Allow"
        ip_address_range = "0.0.0.0/0"
      }]
    }
  }

  assert {
    condition     = length(azurerm_container_app.this) == 0
    error_message = "Express must not create an AzureRM Container App."
  }

  assert {
    condition     = azapi_resource.express[0].body.properties.environmentId != null
    error_message = "Express app must use the environmentId field."
  }

  assert {
    condition     = azapi_resource.express[0].type == "Microsoft.App/containerApps@2026-03-02-preview"
    error_message = "Express apps must default to the currently deployed 2026-03-02-preview ARM contract."
  }

  assert {
    condition     = azapi_resource.express[0].ignore_null_property
    error_message = "Express app requests must omit null properties."
  }

  assert {
    condition     = azapi_resource.express[0].body.properties.template.containers[0].probes[0].type == "Liveness"
    error_message = "Express HTTP probes must be serialized."
  }

  assert {
    condition     = azapi_resource.express[0].body.properties.template.scale.rules[0].http.metadata.concurrentRequests == "50"
    error_message = "Express HTTP scaling must be serialized."
  }
}
