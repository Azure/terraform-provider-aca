terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  environment = {
    environment_mode = "Express"
  }

  container_apps = {
    hello = {
      name          = "${var.name}-hello"
      revision_mode = "Single"

      template = {
        containers = [{
          name              = "hello"
          image             = var.container_image
          cpu               = 0.25
          memory            = "0.5Gi"
          ephemeral_storage = "2Gi"
          liveness_probe = {
            transport        = "HTTP"
            port             = 80
            path             = "/"
            interval_seconds = 30
          }
        }]

        min_replicas = 0
        max_replicas = 3

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
          allowed_methods = ["GET"]
        }

        ip_security_restrictions = [{
          name             = "allow-internet"
          action           = "Allow"
          ip_address_range = "0.0.0.0/0"
          description      = "Example only; restrict this range for production."
        }]
      }
    }
  }
}
