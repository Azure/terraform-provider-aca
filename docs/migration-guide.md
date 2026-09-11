# Migration Guide — AzAPI → AzureRM Feature Migration

> This guide describes how to migrate a feature from the AzAPI overlay back to native AzureRM
> when the AzureRM provider adds support for a previously preview-only capability.

---

## Overview

The Terraform ACA Extension Layer uses a **base + overlay** pattern:

1. **Base**: `azurerm_*` resources handle GA features
2. **Overlay**: `azapi_update_resource` patches preview features onto the base resource

When AzureRM adds native support for a feature that was previously AzAPI-only,
the module should migrate that feature back to AzureRM. This guide walks through
the complete migration workflow.

---

## When to Migrate

Migrate a feature when **all** of the following are true:

- [ ] The AzureRM provider has GA support for the feature
- [ ] The AzureRM resource argument matches or supersedes the AzAPI property
- [ ] The feature has been tested with AzureRM in at least one environment
- [ ] A minor or major module version bump is planned

**Do not migrate** if AzureRM support is still in beta or the argument shape differs
significantly — wait for stabilization.

---

## Migration Workflow

### Express overlay to dedicated AzAPI resources

Earlier revisions of the Express work created the environment and application
with AzureRM and patched `environmentMode` through an AzAPI overlay. Express is
now created directly with dedicated AzAPI resources. Terraform cannot safely
move state between the AzureRM and AzAPI provider resource types automatically.

Before applying an upgrade to an existing Express deployment:

1. Back up the state and record the existing environment and application ARM
   resource IDs.
2. Update the module configuration, but do not run `terraform apply`.
3. Remove the old AzureRM addresses from state. `terraform state rm` does not
   delete the remote Azure resources.
4. Import the same ARM IDs into the new AzAPI addresses.
5. Run `terraform plan` and confirm it contains no deletes or replacements.

For a root module named `aca` and application key `api`:

```powershell
terraform state pull | Set-Content -Encoding utf8 express-state-backup.json

terraform state rm 'module.aca.module.container_app["api"].azurerm_container_app.this'
terraform state rm 'module.aca.module.environment.azurerm_container_app_environment.this'

terraform import 'module.aca.module.environment.azapi_resource.express[0]' '<environment-resource-id>'
terraform import 'module.aca.module.container_app["api"].azapi_resource.express[0]' '<container-app-resource-id>'

terraform plan
```

Repeat the application state removal and import for every Express application.
Address prefixes differ when the environment or application modules are called
directly. Do not run an intervening apply, and do not use `terraform state mv`
across these provider resource types.

---

### Step 1: Update the Capability Registry

Edit `internal/capability_registry.yaml` and update the feature entry:

```yaml
# Before
- feature: container_app_advanced_ingress
  provider: azapi
  api_version: "2024-10-02-preview"
  native_in_azurerm: false
  preview: true
  feature_flag: advanced_ingress

# After
- feature: container_app_advanced_ingress
  provider: azurerm
  api_version: null
  native_in_azurerm: true
  preview: false
  feature_flag: null        # No longer gated
```

### Step 2: Update Module Code

In the affected module (e.g., `modules/container_app/`):

**a) Add the feature to `main.tf`**

Move the AzAPI property into the `azurerm_container_app` resource block:

```hcl
# main.tf — add the argument to the base resource
resource "azurerm_container_app" "this" {
  # ... existing arguments ...
  
  # NEW: previously handled by AzAPI overlay
  additional_port_mappings = var.additional_port_mappings
}
```

**b) Remove the AzAPI overlay from `main_azapi.tf`**

Delete or comment out the `azapi_update_resource` block for this feature:

```hcl
# main_azapi.tf — REMOVE this block
# resource "azapi_update_resource" "advanced_ingress" { ... }
```

**c) Update `variables.tf`**

If the feature was gated behind `feature_flags`, either:
- Remove the flag from the `feature_flags` variable (breaking change → major version)
- Keep the flag but make it a no-op with a deprecation notice (non-breaking)

```hcl
# Deprecation approach (non-breaking)
variable "feature_flags" {
  type = object({
    advanced_ingress = optional(bool, false)  # DEPRECATED: now native in AzureRM
  })
}
```

### Step 3: State Migration

Users who had the AzAPI overlay enabled need to remove the overlay resource from state.
The feature is now managed by the base `azurerm_*` resource.

Generate migration commands using the helper script:

```powershell
.\scripts\migrate-feature.ps1 -Feature "advanced_ingress" -Module "container_app"
```

Or manually:

```bash
# Remove the AzAPI overlay resource from state
terraform state rm 'module.app.azapi_update_resource.advanced_ingress[0]'

# Verify — plan should show no changes (or only the new argument on the base resource)
terraform plan
```

> **Important**: If `terraform plan` shows the base resource being updated (not recreated),
> this is expected — the argument is being added to the AzureRM resource's management scope.
> Run `terraform apply` to reconcile.

### Step 4: Validate

```bash
# Format check
terraform fmt -check -recursive

# Validate all modules
for dir in modules/*/; do
  (cd "$dir" && terraform init -backend=false && terraform validate)
done

# Run tests
terraform test
```

### Step 5: Release

1. Bump module version (minor if non-breaking, major if feature_flag removed)
2. Update CHANGELOG with migration notes
3. Publish to Terraform Registry

---

## Migration Checklist Template

Use this checklist when migrating a feature:

```markdown
## Migration: [feature_name]

- [ ] Verified AzureRM GA support for this feature
- [ ] Updated `internal/capability_registry.yaml`
- [ ] Added feature to `main.tf` base resource
- [ ] Removed AzAPI overlay from `main_azapi.tf`
- [ ] Updated `variables.tf` (deprecated or removed feature flag)
- [ ] Updated `outputs.tf` if needed
- [ ] Generated state migration commands
- [ ] Ran `terraform fmt` and `terraform validate`
- [ ] Ran `terraform test`
- [ ] Updated README/CHANGELOG
- [ ] Version bumped
```

---

## State Migration Reference

| Scenario | Command |
|----------|---------|
| Remove AzAPI overlay | `terraform state rm 'module.<name>.azapi_update_resource.<feature>[0]'` |
| Move resource between modules | `terraform state mv 'module.old.resource' 'module.new.resource'` |
| Import existing resource into module | `terraform import 'module.<name>.azurerm_container_app.this' <resource_id>` |
| Verify no drift | `terraform plan` (should show no changes) |

---

## Currently Migratable Features

The following features are implemented via AzAPI and will be candidates for migration
when AzureRM adds support:

| Feature | Module | API Version | Feature Flag |
|---------|--------|-------------|--------------|
| `container_app_advanced_ingress` | container_app | 2024-10-02-preview | `advanced_ingress` |
| `container_app_kind_functionapp` | container_app | 2025-01-01 | `kind_functionapp` |
| `container_app_dapr_app_health` | container_app | 2024-10-02-preview | `dapr_app_health` |
| `environment_peer_authentication` | container_app_environment | 2024-10-02-preview | `peer_authentication` |
| `jobs_event_trigger_advanced` | jobs | 2024-10-02-preview | `jobs_event_trigger_advanced` |

Monitor the [AzureRM provider changelog](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/CHANGELOG.md)
for new ACA feature additions.
