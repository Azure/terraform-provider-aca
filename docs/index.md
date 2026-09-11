---
title: Overview
description: AzureRM facade module with transparent AzAPI overlay for Azure Container Apps
breadcrumbs:
  - title: Home
    url: /
next_page:
  title: Quick Start
  url: /getting-started
---

<p class="lead">
A Terraform module that provides an AzureRM-native experience for Azure Container Apps
while transparently using AzAPI for features not yet supported by AzureRM — closing
the average <strong>13-month feature gap</strong> without requiring teams to learn a second provider.
</p>

## The Problem

AzureRM's Container Apps provider lags the Azure API by **~13 months on average**. Features
like session affinity, CORS policies, advanced scaling rules, and Java Spring components
are available in Azure but require raw `azapi_update_resource` calls — forcing teams to
manage JSON payloads, learn Azure ARM schemas, and handle state migration when AzureRM
eventually catches up.

## The Solution

This module wraps AzureRM resources and transparently routes to AzAPI when needed:

```hcl
module "aca" {
  source = "github.com/Azure/terraform-provider-aca"

  name                = "my-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  container_apps = {
    api = {
      revision_mode = "Single"
      template = {
        containers = [{
          name   = "api"
          image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
          cpu    = 0.25
          memory = "0.5Gi"
        }]
      }
      ingress = {
        external_enabled = true
        target_port      = 80
      }
      # Enable AzAPI features with a single flag
      feature_flags = {
        advanced_ingress = true
      }
    }
  }
}
```

<div class="feature-grid">
  <div class="feature-card">
    <h4>🏗️ AzureRM-First</h4>
    <p>All base resources use stable <code>azurerm_*</code> resources. AzAPI is only used when AzureRM lacks support.</p>
  </div>
  <div class="feature-card">
    <h4>🔌 Transparent AzAPI</h4>
    <p>Preview features are available without learning AzAPI JSON payloads or ARM schemas.</p>
  </div>
  <div class="feature-card">
    <h4>🔄 Brownfield-Friendly</h4>
    <p>Variable names match AzureRM resource arguments 1:1. Migrate to or from the module trivially.</p>
  </div>
  <div class="feature-card">
    <h4>🏷️ Feature Flags</h4>
    <p>Preview features require explicit opt-in via <code>feature_flags</code>. No surprises.</p>
  </div>
  <div class="feature-card">
    <h4>📋 Capability Registry</h4>
    <p>YAML-based mapping tracks which features use AzureRM vs AzAPI, with migration status.</p>
  </div>
  <div class="feature-card">
    <h4>🤖 Auto-Updated</h4>
    <p>Weekly GitHub Actions workflow detects new ACA API versions and generates coverage PRs.</p>
  </div>
</div>

## How It Works

<div class="mermaid">
graph LR
    User["Your Terraform Code"] --> Module["ACA Extension Module"]
    Module -->|"Base resources"| AzureRM["azurerm provider"]
    Module -->|"Preview features"| AzAPI["azapi provider"]
    AzureRM --> Azure["Azure"]
    AzAPI --> Azure
    style AzureRM fill:#4A90D9,color:#fff
    style AzAPI fill:#E8833A,color:#fff
    style Module fill:#0078D4,color:#fff
</div>

The module examines your `feature_flags` and `provider_overrides` settings. When a feature
is fully supported by AzureRM, it uses `azurerm_*` resources directly. When a feature
requires AzAPI (preview, not yet in AzureRM), it creates the base resource with AzureRM
and applies an `azapi_update_resource` overlay to add the missing properties.

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| azurerm | >= 4.0.0, < 5.0.0 |
| azapi | >= 2.0.0 |

## 15 Deployment-Tested Examples

Every example has been deployed and validated on Azure. Browse them in the sidebar or
see the [Examples Overview]({{ '/examples/' | relative_url }}).
