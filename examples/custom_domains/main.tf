# Custom Domains Example — Terraform ACA Extension Layer
#
# Demonstrates custom domain binding with managed certificate for Azure
# Container Apps. The domain binding is conditional — when var.custom_domain
# is empty (default), the app deploys without a custom domain. Set the
# variable to a real domain to enable DNS validation and certificate provisioning.

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
# ACA Module — Environment + App
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  observability = {
    create_log_analytics_workspace = true
    create_application_insights    = true
  }

  container_apps = {
    web = {
      revision_mode = "Single"

      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "web-app"
          image  = var.container_image
          cpu    = 0.5
          memory = "1Gi"

          env = [
            { name = "CUSTOM_DOMAIN", value = var.custom_domain != "" ? var.custom_domain : "none" },
          ]
        }]
      }

      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
        traffic_weight = [{ latest_revision = true, percentage = 100 }]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Custom Domain Binding (conditional — only when var.custom_domain is set)
# ---------------------------------------------------------------------------
# The custom domain flow is a multi-step process:
#   1. Create a CNAME/TXT DNS record pointing to the ACA environment
#   2. Terraform creates the custom domain resource (triggers DNS validation)
#   3. Azure provisions a managed certificate automatically
#
# Prerequisites before applying with a custom domain:
#   - You own the domain and can create DNS records
#   - A CNAME record: <subdomain> → <environment_default_domain>
#   - A TXT record: asuid.<subdomain> → <custom_domain_verification_id>

resource "azurerm_container_app_custom_domain" "this" {
  count = var.custom_domain != "" ? 1 : 0

  name             = var.custom_domain
  container_app_id = module.aca.container_apps["web"].id

  # For managed certificates, the certificate binding type is set after the
  # certificate is provisioned. Use lifecycle ignore to prevent drift.
  lifecycle {
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }
}
