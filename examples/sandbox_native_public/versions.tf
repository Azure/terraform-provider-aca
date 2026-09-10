terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aca = {
      source  = "Azure/aca"
      version = "0.1.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.12.0, < 3.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "aca" {
  use_azure_cli = true
}
