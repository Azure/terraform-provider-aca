---
title: Architecture
description: How the ACA Extension Layer module is structured internally
breadcrumbs:
  - title: Home
    url: /
  - title: Architecture
    url: /architecture
prev_page:
  title: Quick Start
  url: /getting-started
next_page:
  title: Modules
  url: /modules
---

<p class="lead">
The module uses a sub-module composition pattern where the root module orchestrates
five specialized sub-modules, with AzAPI overlays applied conditionally based on
feature flags.
</p>

## Module Composition

<div class="mermaid">
graph TD
    Root["Root Module<br/><i>main.tf</i>"]

    subgraph Sub-Modules
        NET["modules/networking<br/><i>VNet · Subnet · NSG</i>"]
        OBS["modules/observability<br/><i>Log Analytics · App Insights</i>"]
        ENV["modules/container_app_environment<br/><i>Environment · Workload Profiles</i>"]
        APP["modules/container_app<br/><i>for_each container_apps</i>"]
        JOB["modules/jobs<br/><i>for_each jobs</i>"]
    end

    Root -->|"when networking set"| NET
    Root -->|"when observability set"| OBS
    Root -->|always| ENV
    Root -->|for_each| APP
    Root -->|for_each| JOB

    NET -->|subnet_id| ENV
    OBS -->|workspace_id| ENV
    ENV -->|environment_id| APP
    ENV -->|environment_id| JOB

    style NET fill:#4A90D9,color:#fff
    style OBS fill:#4A90D9,color:#fff
    style ENV fill:#4A90D9,color:#fff
    style APP fill:#4A90D9,color:#fff
    style JOB fill:#4A90D9,color:#fff

    AZAPI["AzAPI Overlay<br/><i>azapi_update_resource</i>"]
    APP -.->|"when feature_flags set"| AZAPI
    ENV -.->|"when preview features"| AZAPI
    JOB -.->|"when preview features"| AZAPI
    style AZAPI fill:#E8833A,color:#fff
</div>

**Blue** = AzureRM resources (stable) · **Orange** = AzAPI resources (preview/unsupported features)

## The AzAPI Overlay Pattern

The key architectural pattern is the **AzAPI overlay**. Rather than choosing between
AzureRM *or* AzAPI for an entire resource, this module:

1. **Creates the base resource with AzureRM** — leveraging full plan/state support
2. **Applies an `azapi_update_resource` overlay** — adding properties that AzureRM doesn't support

```hcl
# Step 1: Base resource via AzureRM (in modules/container_app/main.tf)
resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = var.environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  # ... standard AzureRM configuration
}

# Step 2: AzAPI overlay (in modules/container_app/main_azapi.tf)
resource "azapi_update_resource" "advanced_ingress" {
  count       = var.feature_flags.advanced_ingress ? 1 : 0
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.this.id

  body = {
    properties = {
      configuration = {
        ingress = {
          additionalPortMappings = var.additional_port_mappings
        }
      }
    }
  }
}
```

This pattern means:
- **No state migration needed** — the base AzureRM resource exists in state normally
- **Incremental adoption** — add one AzAPI feature at a time
- **Easy migration back** — when AzureRM adds support, remove the overlay and the
  feature flag; run `terraform state rm` on the overlay resource

## Provider Split

| Concern | Provider | Rationale |
|---------|----------|-----------|
| Container App (base) | `azurerm` | Full plan/diff, stable lifecycle |
| Container App Environment | `azurerm` | VNet integration, workload profiles |
| Jobs | `azurerm` | CRON/event triggers, retry policies |
| Networking (VNet, Subnet, NSG) | `azurerm` | Mature, well-tested |
| Observability (LAW, App Insights) | `azurerm` | Standard resources |
| Session affinity | `azapi` | Not in AzureRM |
| CORS policies | `azapi` | Not in AzureRM |
| Additional port mappings | `azapi` | Not in AzureRM |
| Custom scale rules | `azapi` | Limited in AzureRM |
| Java components (Eureka, Config) | `azapi` | Not in AzureRM |
| Session pools | `azapi` | Not in AzureRM |
| Init containers (overlay) | `azapi` | Limited in AzureRM |

## Capability Registry

The [`internal/capability_registry.yaml`](https://github.com/Azure/terraform-provider-aca/blob/main/internal/capability_registry.yaml)
file is the source of truth for which features use which provider. It tracks:

- Feature name and description
- Current provider (`azurerm`, `azapi`, or `both`)
- API version required
- Whether AzureRM supports it natively
- Migration status

## Conditional Sub-Module Instantiation

Sub-modules are only created when their input variables are provided:

```hcl
# Networking is optional — only created if var.networking is set
module "networking" {
  count  = var.networking != null ? 1 : 0
  source = "./modules/networking"
  # ...
}

# Observability is optional
module "observability" {
  count  = var.observability != null ? 1 : 0
  source = "./modules/observability"
  # ...
}

# Environment is always created
module "environment" {
  source = "./modules/container_app_environment"
  # Uses subnet_id from networking if available
  subnet_id = var.networking != null ? module.networking[0].subnet_id : null
  # ...
}

# Apps are created for each entry in var.container_apps
module "container_app" {
  for_each = var.container_apps
  source   = "./modules/container_app"
  # ...
}
```

## Known Gotchas

<div class="callout callout-warning">
  <div class="callout-title">Subnet Delegation</div>
  <strong>Consumption-only</strong> environments reject pre-delegated subnets — ACA sets delegation itself.
  <strong>Workload profiles</strong> environments require pre-delegated subnets.
  The networking module uses <code>ignore_changes = [delegation]</code> to handle both cases.
</div>

<div class="callout callout-warning">
  <div class="callout-title">Private Endpoints</div>
  Private endpoints require a <strong>workload profiles</strong> environment. Consumption-only
  environments return <code>PrivateEndpointUnsupportedForConsumptionOnlyEnv</code>.
</div>

<div class="callout callout-note">
  <div class="callout-title">Environment Provisioning Times</div>
  Without VNet: ~1 minute. With VNet (consumption): ~8–10 minutes. With VNet (workload profiles): ~3–4 minutes.
</div>
