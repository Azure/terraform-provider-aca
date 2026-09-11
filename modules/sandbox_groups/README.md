# ACA Sandbox Groups

Manages the ARM control plane for Azure Container Apps Sandboxes:

- `Microsoft.App/sandboxGroups`;
- `Microsoft.App/sandboxGroups/vnetConnections`;
- optional SandboxGroup Data Owner role assignments;
- optional AcrPull assignments for the group identity;
- optional `CanNotDelete` management lock.

Individual Sandboxes, disks, snapshots, volumes, files, secrets, ports, and
egress policies use the regional ACA data plane. They are not ARM resources and
are not managed by this module.

## API profiles

| Profile | API | Supported inputs |
|---|---|---|
| `stable` (default) | `2026-02-01-preview` | tags and VNet connections; minimal stable-shaped body |
| `rich_preview` | `2026-02-01-preview` | group CPU/memory/disk defaults, maximum count, timeout, managed identity, VNet connections |

The profile name controls the field set, not API maturity. Azure currently
registers only `2026-02-01-preview` for Sandbox Groups, so both profiles use it
by default. The `stable` profile sends a minimal body and does not inject
preview defaults. `environment_id` is retained for forward compatibility and
requires an explicit `api_version` override to a registered contract that
exposes that field.

```hcl
module "sandbox_group" {
  source = "github.com/Azure/terraform-provider-aca//modules/sandbox_groups"

  name              = "agent-sandboxes"
  resource_group_id = azurerm_resource_group.this.id
  location          = "swedencentral"
  api_profile       = "rich_preview"

  identity = {
    type = "SystemAssigned"
  }

  default_cpu       = "2"
  default_memory    = "4Gi"
  default_disk      = "32Gi"
  max_sandbox_count = 10

  vnet_connections = {
    primary = {
      subnet_id = azurerm_subnet.sandbox.id
    }
  }

  data_plane_operators = {
    caller = {
      principal_id   = data.azurerm_client_config.current.object_id
      principal_type = "User"
    }
  }

  acr_pull_assignments = {
    images = {
      scope = azurerm_container_registry.this.id
    }
  }

  lock_enabled = true
}
```

The VNet subnet must be delegated to `Microsoft.App/environments`. A VNet
connection's subnet cannot be changed after creation.

Use `experimental/sandbox_workload` when Terraform-driven create-or-reuse
orchestration is needed for individual data-plane Sandboxes. That companion
never deletes data-plane resources during destroy.
