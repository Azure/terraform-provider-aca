# Enterprise App Example — Terraform ACA Extension Layer
#
# Demonstrates a production-like deployment with:
# - VNet integration (dedicated subnet)
# - Observability (Log Analytics + Application Insights)
# - Managed identity (system-assigned)
# - Workload profiles (dedicated compute)
# - Tags for cost management

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
}

# ---------------------------------------------------------------------------
# ACA Module — Enterprise Configuration
# ---------------------------------------------------------------------------

module "aca" {
  source = "../../"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = {
    Environment = var.environment
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
  }

  # --- Networking: VNet-integrated environment ---
  networking = {
    create_vnet               = true
    vnet_address_space        = var.vnet_address_space
    aca_subnet_address_prefix = var.aca_subnet_address_prefix
    create_nsg                = true
    nsg_rules = [
      {
        name                       = "allow-https-inbound"
        priority                   = 200
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ]
  }

  # --- Observability: Full stack monitoring ---
  observability = {
    create_log_analytics_workspace  = true
    log_analytics_retention_in_days = 90
    create_application_insights     = true
    application_insights_type       = "web"
  }

  # --- Environment: Workload profiles for dedicated compute ---
  environment = {
    zone_redundancy_enabled = false
    mutual_tls_enabled      = true
    workload_profile = [
      {
        name                  = "dedicated-d4"
        workload_profile_type = "D4"
        minimum_count         = 1
        maximum_count         = 3
      }
    ]
  }

  # --- Container App: Production API ---
  container_apps = {
    api = {
      revision_mode = "Single"

      template = {
        min_replicas = var.min_replicas
        max_replicas = var.max_replicas

        containers = [
          {
            name   = "api"
            image  = var.container_image
            cpu    = 0.5
            memory = "1Gi"

            env = [
              { name = "ASPNETCORE_ENVIRONMENT", value = var.environment },
            ]
          }
        ]
      }

      ingress = {
        external_enabled = true
        target_port      = var.container_port
        transport        = "auto"
        traffic_weight = [
          { latest_revision = true, percentage = 100 }
        ]
      }

      identity = {
        type = "SystemAssigned"
      }

      workload_profile_name = "dedicated-d4"

      tags = {
        Service = "api"
        Team    = "backend"
      }
    }
  }
}
