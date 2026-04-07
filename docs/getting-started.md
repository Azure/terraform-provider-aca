---
title: Quick Start
description: Get up and running with the Terraform ACA Extension Layer in minutes
breadcrumbs:
  - title: Home
    url: /
  - title: Quick Start
    url: /getting-started
prev_page:
  title: Overview
  url: /
next_page:
  title: Architecture
  url: /architecture
---

<p class="lead">
Deploy your first Azure Container App with the extension layer in under 5 minutes.
</p>

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | >= 1.5.0 |
| AzureRM provider | >= 4.0.0 |
| AzAPI provider | >= 2.0.0 |
| Azure CLI | Latest (`az login` authenticated) |
| Azure Subscription | With `Microsoft.App` resource provider registered |

## Step 1: Authenticate

```bash
az login
az account set --subscription "your-subscription-id"
```

## Step 2: Create Your Configuration

Create a new directory and add `main.tf`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-aca-quickstart"
  location = "swedencentral"
}

module "aca" {
  source = "github.com/Azure/terraform-provider-aca"

  name                = "aca-quickstart"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  container_apps = {
    hello = {
      revision_mode = "Single"
      template = {
        containers = [{
          name   = "hello"
          image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
          cpu    = 0.25
          memory = "0.5Gi"
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
      }
    }
  }
}
```

## Step 3: Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

<div class="callout callout-note">
  <div class="callout-title">Note</div>
  Environment provisioning typically takes 1–3 minutes. With VNet integration, expect 8–10 minutes.
</div>

## Step 4: Verify

```bash
# Get the app URL
terraform output -json | jq -r '.app_urls.value'

# Open in browser or curl
curl https://<your-app-url>
```

## Step 5: Clean Up

```bash
terraform destroy
```

## Next Steps

- Add [networking and VNet integration]({{ '/examples/simple-app' | relative_url }}) for production workloads
- Enable [observability]({{ '/examples/enterprise-app' | relative_url }}) with App Insights
- Explore [preview features]({{ '/feature-flags' | relative_url }}) like session affinity and CORS policies
- Browse all [16 examples]({{ '/examples/' | relative_url }})

## Using an Existing Example

All examples are self-contained. Clone and deploy any of them:

```bash
git clone https://github.com/Azure/terraform-provider-aca.git
cd terraform-provider-aca/examples/simple_app

terraform init
terraform plan -var="subscription_id=YOUR_SUB_ID" -out=tfplan
terraform apply tfplan
```
