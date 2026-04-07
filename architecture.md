# Architecture — Terraform Extension Layer for Azure Container Apps

> Phase 1 Architecture Reference Implementation

---

## 1. Overview

This module provides a **facade layer** over Azure Container Apps (ACA) resources.
It exposes a Terraform-native interface that mirrors AzureRM resource arguments
while transparently routing to AzAPI for features not yet supported by AzureRM.

```
┌─────────────────────────────────────────────────┐
│               User Terraform Code               │
│  module "app" { source = "./modules/container_app" ... }  │
└────────────────────────┬────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│            Facade Module Layer                   │
│                                                  │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │ AzureRM Base │  │ AzAPI Overlay (optional)  │ │
│  │  Resources   │  │  via feature_flags        │ │
│  └──────┬───────┘  └──────────┬───────────────┘ │
│         │                     │                  │
│         ▼                     ▼                  │
│  ┌──────────────────────────────────────────┐   │
│  │       Capability Registry (YAML)         │   │
│  │  Maps features → providers + API versions │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│              Azure Resource Manager              │
└─────────────────────────────────────────────────┘
```

---

## 2. Design Principles

| # | Principle | Rationale |
|---|-----------|-----------|
| 1 | **AzureRM-first** | Use `azurerm_*` resources as the base implementation for stability and ecosystem compatibility. |
| 2 | **AzAPI overlay, not replacement** | Use `azapi_update_resource` to patch additional properties onto AzureRM-created resources. Never use `azapi_resource` as a full replacement. |
| 3 | **Thin wrapper** | Module variables mirror AzureRM resource arguments 1:1. Brownfield users can migrate with minimal code changes. |
| 4 | **Explicit preview opt-in** | Preview features require `feature_flags = { feature_name = true }`. No silent AzAPI usage. |
| 5 | **Internal capability registry** | YAML file documents which provider handles each feature. Agents and maintainers use this as the source of truth. |
| 6 | **Stable interface** | Input variables never change in minor/patch versions. Internal routing may change freely. |

---

## 3. Provider Routing Pattern

The module uses a **base + overlay** pattern:

### Step 1: AzureRM Base Resource
Every ACA resource is created via AzureRM. This provides:
- Stable state management
- Familiar plan output
- Ecosystem tool compatibility (Sentinel, tflint, etc.)

### Step 2: AzAPI Overlay (Conditional)
When a user enables a preview feature via `feature_flags`, an `azapi_update_resource`
patches the AzureRM-created resource with additional properties from a newer API version.

```hcl
# Base resource (always created)
resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = var.revision_mode
  template { ... }
}

# Overlay (only when feature flag is enabled)
resource "azapi_update_resource" "advanced_ingress" {
  count = var.feature_flags.advanced_ingress ? 1 : 0

  type        = "Microsoft.App/containerApps@2024-10-02-preview"
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

### Provider Override
Advanced users can force provider routing via `provider_overrides`:
```hcl
module "app" {
  source = "./modules/container_app"
  # ...
  provider_overrides = {
    advanced_ingress = "azurerm"  # skip AzAPI even if flag is set
  }
}
```

---

## 4. Module Structure

```
terraform-provider-aca/
│
├── modules/
│   ├── container_app_environment/     # ACA Environment
│   │   ├── main.tf                    # azurerm_container_app_environment
│   │   ├── main_azapi.tf             # AzAPI overlays for preview features
│   │   ├── variables.tf              # Mirrors azurerm arguments
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   │
│   ├── container_app/                 # ACA Container App
│   │   ├── main.tf                    # azurerm_container_app
│   │   ├── main_azapi.tf             # AzAPI overlays
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   │
│   ├── jobs/                          # ACA Jobs
│   │   ├── main.tf                    # azurerm_container_app_job
│   │   ├── main_azapi.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   │
│   ├── networking/                    # VNet/Subnet/NSG for ACA
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   │
│   └── observability/                 # Log Analytics + Diagnostics
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
│
├── internal/
│   └── capability_registry.yaml       # Feature → provider mapping
│
├── examples/
│   └── simple_app/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── tests/
│   └── README.md
│
├── main.tf                            # Root module composing submodules
├── variables.tf                       # Root variables
├── outputs.tf                         # Root outputs
├── versions.tf                        # Provider requirements
├── architecture.md                    # This document
├── project-constraints.md             # Discovery interview results
└── README.md                          # User-facing documentation
```

---

## 5. Capability Registry

The capability registry (`internal/capability_registry.yaml`) is a declarative
mapping of ACA features to their implementing provider. It serves as:

- **Documentation**: Which features use AzAPI vs AzureRM
- **Agent reference**: Engineering agents consult this when adding features
- **Migration tracker**: When AzureRM adds support, update the registry

Each entry contains:
```yaml
- feature: <feature_name>
  description: <human-readable description>
  resource_type: <ARM resource type>
  provider: azurerm | azapi
  api_version: <API version if azapi>
  native_in_azurerm: true | false
  preview: true | false
  feature_flag: <flag name if preview>
```

---

## 6. Feature Flags

The `feature_flags` variable is a map of booleans gating preview features:

```hcl
variable "feature_flags" {
  description = "Enable preview ACA features (uses AzAPI under the hood)"
  type = object({
    advanced_ingress    = optional(bool, false)
    custom_domains_cert = optional(bool, false)
    app_health_probes   = optional(bool, false)
    kind_functionapp    = optional(bool, false)
  })
  default = {}
}
```

Each flag corresponds to a capability registry entry. When enabled:
1. The module creates an `azapi_update_resource` to patch the feature
2. Plan output shows both the base resource and the overlay
3. The user is informed via variable description that this uses a preview API

---

## 7. Brownfield Migration Path

For users migrating from `azurerm_container_app` to this module:

1. **Replace** the `azurerm_container_app` resource block with a `module` call
2. **Map** the same arguments (variable names match 1:1)
3. **Run** `terraform state mv azurerm_container_app.app module.app.azurerm_container_app.this`
4. **Verify** with `terraform plan` — should show no changes

Example migration:
```hcl
# Before (direct AzureRM)
resource "azurerm_container_app" "api" {
  name                         = "my-api"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  template { ... }
}

# After (facade module)
module "api" {
  source                       = "./modules/container_app"
  name                         = "my-api"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  template = { ... }
}
```

---

## 8. AVM Alignment

The module follows Azure Verified Module conventions:
- Standardized file layout (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`)
- Consistent variable naming
- Tags propagation
- Managed identity support as a first-class variable
- Diagnostic settings integration
- README.md per module with usage examples

---

## 9. Constraints Reference

See `project-constraints.md` for the full set of architectural constraints
established during the Phase 0 discovery interview.
