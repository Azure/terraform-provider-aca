---
mode: agent
description: "Analyze a new ACA API version, add module coverage for new features, create examples, and open a PR"
tools:
  - powershell
  - view
  - edit
  - create
  - grep
  - glob
---

# New ACA API Version Coverage

You are updating the Terraform ACA Extension Layer to cover features introduced
in a new Azure Container Apps API version. Follow these steps exactly.

## Context

Read these files first to understand the repo and current coverage:
- `.github/copilot-instructions.md` — repo conventions and patterns
- `docs/api-versions.json` — current feature registry (this is your source of truth)
- `modules/container_app/main_azapi.tf` — existing AzAPI overlays
- `modules/container_app/variables.tf` — existing feature flags

## Step 1: Discover New Features

Compare the new API version's swagger/changelog against `docs/api-versions.json`.
For each resource type (`containerApps`, `managedEnvironments`, `jobs`, `sessionPools`):

1. Fetch the API changelog from `https://learn.microsoft.com/en-us/azure/container-apps/whats-new`
2. Identify properties/resources that are:
   - **New** (not in `api-versions.json` features list)
   - **Newly GA** (were preview, now GA)
   - **Changed** (breaking changes to existing properties)
3. For each new feature, check if AzureRM already supports it by searching the
   [AzureRM provider changelog](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/CHANGELOG.md)

## Step 2: Update the API Version Registry

Edit `docs/api-versions.json`:
- Update `latest_api_version` and/or `latest_preview_version`
- Update `resource_types` with new API versions
- Add entries to `features[]` for each new feature with:
  - `name`, `api_version_introduced`, `azurerm_supported`, `module_supported: false`, `example: null`
  - `resource_path` — the ARM property path

## Step 3: Add Module Support

For each new feature where `azurerm_supported = false`:

### 3a. Add Feature Flag
In `modules/container_app/variables.tf`, add the feature to the `feature_flags` object:
```hcl
new_feature = optional(bool, false)
```

### 3b. Add AzAPI Overlay
In `modules/container_app/main_azapi.tf`, add an `azapi_update_resource` block:
```hcl
resource "azapi_update_resource" "new_feature" {
  count = var.feature_flags.new_feature && lookup(var.provider_overrides, "new_feature", "azapi") == "azapi" ? 1 : 0

  type        = "Microsoft.App/containerApps@{NEW_API_VERSION}"
  resource_id = azurerm_container_app.this.id

  body = {
    properties = {
      # ... new feature properties
    }
  }

  depends_on = [azurerm_container_app.this]
}
```

### 3c. Add Variables
Add any new input variables needed for the feature configuration.

### 3d. Update Registry
Set `module_supported: true` in `docs/api-versions.json` for the feature.

## Step 4: Create Example

For each feature worth demonstrating (use judgment — skip trivial boolean flags):

1. Create `examples/{feature_name}/` with 4 files:
   - `main.tf` — full working example using the module
   - `variables.tf` — with sensible defaults
   - `outputs.tf` — key resource IDs and URLs
   - `terraform.tfvars` — default values for the example

2. Follow these conventions:
   - Resource group: `tf-aca-{N}` (use next available number)
   - Region: `swedencentral`
   - Tags: `environment = "dev"`, `managed_by = "terraform"`
   - Include observability (Log Analytics) unless the example is intentionally minimal
   - Use `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` as default image

3. Validate: `terraform init && terraform validate`

4. Update `docs/api-versions.json` with the example name.

## Step 5: Update Documentation

- Add the new example to the table in `README.md` under "## Examples"
- Update `docs/api-versions.json` as the single source of truth

## Step 6: Create PR

Create a branch and commit:
```
git checkout -b feat/api-{VERSION}-coverage
git add .
git commit -m "feat: add coverage for ACA API {VERSION}

- Added module support for: {list features}
- Created examples: {list examples}
- Updated api-versions.json registry

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push origin feat/api-{VERSION}-coverage
```

Then open a PR with:
- Title: `feat: ACA API {VERSION} coverage`
- Body: summary of new features, module changes, and examples added
- Label: `api-update`

## Decision Framework

When deciding whether a feature needs an example:
- **Yes**: AzAPI-only features (not in AzureRM) — these are our key value prop
- **Yes**: Features with >10% adoption in the telemetry data
- **Yes**: Features that represent a common architecture pattern (security, networking, scaling)
- **Maybe**: Features already in AzureRM but with our module providing better ergonomics
- **No**: Trivial boolean toggles that don't need a full example
- **No**: Features with <2% adoption and no clear architecture pattern
