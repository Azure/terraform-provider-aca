# Copilot Instructions — Terraform ACA Extension Layer

## What This Repo Is

This is a **Terraform facade module** for Azure Container Apps (ACA) that wraps AzureRM
and transparently uses AzAPI for preview/unsupported features. The key design pattern is:

- **AzureRM for GA features** — standard `azurerm_container_app`, `azurerm_container_app_environment`, etc.
- **AzAPI overlays for gaps** — `azapi_update_resource` patches properties that AzureRM doesn't expose yet
- **Feature flags** — users opt into AzAPI features via `feature_flags = { sticky_sessions = true }` without changing their module calls

## Repo Structure

```
├── modules/
│   ├── container_app/          # Main app module (azurerm + azapi overlays)
│   ├── container_app_environment/  # Environment module
│   ├── jobs/                   # Container App Jobs
│   ├── networking/             # VNet, subnet, NSG
│   └── observability/          # Log Analytics, App Insights
├── examples/                   # 16 deployable examples (each has main.tf, variables.tf, outputs.tf, terraform.tfvars)
├── docs/
│   ├── api-versions.json       # Registry of tracked ACA API versions and feature coverage
│   └── migration-guide.md
├── tests/
└── scripts/
```

## AzAPI Overlay Pattern

When adding support for a new ACA feature not yet in AzureRM:

1. **Add a feature flag** in `modules/container_app/variables.tf` under the `feature_flags` object
2. **Add an `azapi_update_resource`** in `modules/container_app/main_azapi.tf` that patches the property
3. **Use count conditional**: `count = var.feature_flags.new_feature && lookup(var.provider_overrides, "new_feature", "azapi") == "azapi" ? 1 : 0`
4. **Target the latest GA API version** (e.g., `Microsoft.App/containerApps@2025-01-01`)
5. **Create an example** in `examples/` showing the feature in action

## ACA API Versions

The ACA team publishes new API versions at `Microsoft.App`. Key resource types:
- `Microsoft.App/containerApps` — the apps themselves
- `Microsoft.App/managedEnvironments` — environments (VNet, workload profiles)
- `Microsoft.App/managedEnvironments/javaComponents` — Java Spring components
- `Microsoft.App/sessionPools` — dynamic sessions
- `Microsoft.App/jobs` — container app jobs

API versions follow the pattern: `YYYY-MM-DD` (GA) or `YYYY-MM-DD-preview` (preview).

## Key Conventions

- **Terraform binary**: use `terraform` (or a path specified in the task)
- **Region**: examples default to `swedencentral`
- **Tags**: all resources get `environment = "dev"` and `managed_by = "terraform"`
- **Naming**: examples use `aca-{feature}` prefix for resources
- **Resource groups**: examples deploy to `tf-aca-N` resource groups (N = example number)
- **Subnet delegation**: Consumption-only environments must NOT have pre-delegated subnets (ACA sets it). Workload profiles environments REQUIRE pre-delegation.
- **`ignore_changes = [delegation]`** on all ACA subnets to prevent Terraform drift

## Testing

- `terraform validate` must pass for all examples
- `terraform plan` should produce a clean plan
- Deploy with `terraform apply -auto-approve` to a test resource group
