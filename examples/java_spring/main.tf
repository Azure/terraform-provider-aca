# Java Spring Cloud Components Example — Terraform ACA Extension Layer
#
# Demonstrates Java Spring Cloud components (Eureka, Config Server) on ACA.
# These are environment-level resources not available in azurerm — we use
# sub-module composition with azapi_resource to create the Java components
# and bind them to a container app via service binds.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Observability — Log Analytics Workspace
# ---------------------------------------------------------------------------

module "observability" {
  source = "../../modules/observability"

  name_prefix         = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  create_log_analytics_workspace  = true
  log_analytics_retention_in_days = 30
}

# ---------------------------------------------------------------------------
# Container App Environment
# ---------------------------------------------------------------------------

module "environment" {
  source = "../../modules/container_app_environment"

  name                       = "${var.name}-env"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# Java Components — Spring Cloud Eureka + Config Server (AzAPI)
# ---------------------------------------------------------------------------
# These are environment-level managed Java components that have no azurerm
# equivalent. We create them via azapi_resource and bind them to the app.

resource "azapi_resource" "eureka" {
  type      = "Microsoft.App/managedEnvironments/javaComponents@2025-01-01"
  name      = "eureka"
  parent_id = module.environment.id

  body = {
    properties = {
      componentType  = "SpringCloudEureka"
      configurations = []
    }
  }
}

resource "azapi_resource" "config_server" {
  count     = var.enable_config_server ? 1 : 0
  type      = "Microsoft.App/managedEnvironments/javaComponents@2025-01-01"
  name      = "configserver"
  parent_id = module.environment.id

  body = {
    properties = {
      componentType = "SpringCloudConfig"
      configurations = [
        {
          propertyName = "spring.cloud.config.server.git.uri"
          value        = var.config_git_uri
        }
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# Java Application — Spring Boot app bound to Java components
# ---------------------------------------------------------------------------

module "java_app" {
  source     = "../../modules/container_app"
  depends_on = [azapi_resource.eureka, azapi_resource.config_server]

  name                         = "${var.name}-app"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.environment.id
  revision_mode                = "Single"

  template = {
    min_replicas = 1
    max_replicas = 5
    containers = [{
      name   = "spring-app"
      image  = var.container_image
      cpu    = 1.0
      memory = "2Gi"
      env = [
        { name = "SPRING_PROFILES_ACTIVE", value = "cloud" },
      ]
    }]
  }

  ingress = {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight = [{ latest_revision = true, percentage = 100 }]
  }
}

# ---------------------------------------------------------------------------
# Java Component Bindings — serviceBinds via AzAPI
# ---------------------------------------------------------------------------
# Service binds inject connection information (URLs, credentials) into the
# app's environment at runtime so the Spring Boot app can discover Eureka
# and Config Server without manual configuration.

resource "azapi_update_resource" "java_bindings" {
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = module.java_app.id

  body = {
    properties = {
      template = {
        serviceBinds = concat(
          [
            {
              serviceId = azapi_resource.eureka.id
              name      = "eureka"
            }
          ],
          var.enable_config_server ? [
            {
              serviceId = azapi_resource.config_server[0].id
              name      = "configserver"
            }
          ] : []
        )
      }
    }
  }
}
