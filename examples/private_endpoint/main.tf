# Private Endpoint Example — Terraform ACA Extension Layer
#
# Demonstrates private endpoint for ACA environment via azurerm_private_endpoint.
# Private endpoints for ACA environments just went GA in API 2025-07-01 but are
# NOT yet in the AzureRM provider. This example uses the sub-module composition
# pattern (like the storage example) so we can create the VNet, environment,
# private endpoint, private DNS zone, and container app in the correct order.

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

locals {
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    pattern     = "PrivateEndpoint"
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Virtual Network + Subnets
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.2.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "aca" {
  name                 = "aca-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.2.0.0/23"]

  # Workload profiles environments require pre-delegation
  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "pe" {
  name                 = "pe-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.2.2.0/24"]
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

module "observability" {
  source = "../../modules/observability"

  name_prefix         = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  create_log_analytics_workspace = true
  tags                           = local.tags
}

# ---------------------------------------------------------------------------
# ACA Environment (internal load balancer for private access)
# ---------------------------------------------------------------------------

module "environment" {
  source = "../../modules/container_app_environment"

  name                           = var.name
  resource_group_name            = azurerm_resource_group.this.name
  location                       = azurerm_resource_group.this.location
  log_analytics_workspace_id     = module.observability.log_analytics_workspace_id
  infrastructure_subnet_id       = azurerm_subnet.aca.id
  internal_load_balancer_enabled = true
  tags                           = local.tags

  # Private endpoints require a workload profiles environment
  workload_profile = [{
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }]
}

# ---------------------------------------------------------------------------
# Private DNS Zone + VNet Link
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "aca" {
  name                = "privatelink.${var.location}.azurecontainerapps.io"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca" {
  name                  = "${var.name}-dns-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.aca.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

# ---------------------------------------------------------------------------
# Private Endpoint for ACA Environment
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "aca" {
  name                = "${var.name}-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = module.environment.id
    subresource_names              = ["managedEnvironments"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.aca.id]
  }
}

# ---------------------------------------------------------------------------
# Container App (internal ingress only — accessible via private endpoint)
# ---------------------------------------------------------------------------

module "container_app" {
  source = "../../modules/container_app"

  name                         = "${var.name}-app"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.environment.id
  revision_mode                = "Single"

  template = {
    min_replicas = 1
    max_replicas = 3

    containers = [{
      name   = "private-app"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env = [
        { name = "NETWORK_MODE", value = "private" },
      ]
    }]
  }

  ingress = {
    external_enabled = false
    target_port      = 80
    transport        = "auto"
    traffic_weight = [
      { latest_revision = true, percentage = 100 }
    ]
  }

  tags = local.tags

  depends_on = [azurerm_private_endpoint.aca]
}
