---
title: Migration Guide
description: How to migrate AzAPI overlay features back to AzureRM when native support arrives
breadcrumbs:
  - title: Home
    url: /
  - title: Migration Guide
    url: /migration
prev_page:
  title: API Coverage
  url: /api-coverage
next_page:
  title: Examples
  url: /examples/
---

<p class="lead">
When AzureRM adds native support for a feature that was previously handled by an AzAPI
overlay, follow this guide to migrate cleanly without destroying and recreating resources.
</p>

## Migration Overview

The migration process has three steps:

1. **Update the module** — move the feature configuration from AzAPI overlay to AzureRM resource
2. **Remove the overlay from state** — `terraform state rm` the `azapi_update_resource`
3. **Remove the feature flag** — the feature is now handled natively by AzureRM

## Step-by-Step

### 1. Check AzureRM Support

Verify the feature is now supported in your AzureRM provider version:

```bash
terraform providers lock -platform=linux_amd64
terraform version
```

Check the [AzureRM changelog](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/CHANGELOG.md)
for the specific feature.

### 2. Update the Module

In the sub-module (e.g., `modules/container_app/main.tf`), move the AzAPI-only configuration
into the AzureRM resource block:

```hcl
# Before: Feature handled by AzAPI overlay
resource "azurerm_container_app" "this" {
  # ... base config only
}

resource "azapi_update_resource" "cors_policy" {
  count       = var.feature_flags.cors_policy ? 1 : 0
  resource_id = azurerm_container_app.this.id
  # ... CORS config as JSON
}

# After: Feature handled natively by AzureRM
resource "azurerm_container_app" "this" {
  # ... base config
  ingress {
    # ... existing ingress config
    cors {
      allowed_origins = var.cors_policy.allowed_origins
      allowed_methods = var.cors_policy.allowed_methods
      # ...
    }
  }
}
```

### 3. Remove Overlay from State

```bash
# Find the overlay resource address
terraform state list | grep azapi_update_resource

# Remove it (does NOT destroy the Azure resource)
terraform state rm 'module.container_app["api"].azapi_update_resource.cors_policy[0]'
```

### 4. Remove the Feature Flag

Update your calling code to remove the feature flag:

```hcl
# Before
container_apps = {
  api = {
    feature_flags = {
      cors_policy = true  # Remove this
    }
    cors_policy = { ... }  # Keep this — now handled by AzureRM
  }
}

# After
container_apps = {
  api = {
    cors_policy = { ... }  # AzureRM handles it natively
  }
}
```

### 5. Plan and Verify

```bash
terraform plan
```

The plan should show **no changes** if the migration was done correctly. The AzureRM
resource now manages the feature natively, and the AzAPI overlay has been cleanly removed
from state.

## Helper Script

A migration helper script is provided at `scripts/migrate-feature.ps1`:

```powershell
# Generate migration commands for a specific feature
.\scripts\migrate-feature.ps1 -Feature "cors_policy" -Module "container_app"
```

The script:
1. Lists all `azapi_update_resource` instances for the feature
2. Generates the `terraform state rm` commands
3. Outputs the module code changes needed

## Update the Capability Registry

After migration, update `internal/capability_registry.yaml` to reflect the new provider:

```yaml
cors_policy:
  provider: azurerm          # Changed from 'azapi'
  azurerm_supported: true    # Changed from false
  migration_status: complete
  migrated_in_version: "4.x.0"
```

<div class="callout callout-warning">
  <div class="callout-title">Important</div>
  Always run <code>terraform plan</code> after migration to verify no resources will be
  destroyed or recreated. The goal is a <strong>zero-disruption</strong> migration where
  only the Terraform state changes — no Azure resources are modified.
</div>
