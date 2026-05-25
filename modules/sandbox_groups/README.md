# `modules/sandbox_groups`

Terraform sub-module for **Azure Container Apps Sandbox Groups**
(`Microsoft.App/sandboxGroups`) — an early-access ACA product that provisions a
pool of disposable Linux VMs ("sandboxes") suitable for AI agent code execution,
untrusted code sandboxing, and per-tenant compute isolation.

This resource type is **not yet supported by AzureRM**, so the module talks
directly to ARM via [`azapi_resource`](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource).

## Two-plane model (important)

| Plane | Endpoint | Resources |
|---|---|---|
| **ARM control plane** | `management.azure.com` | `Microsoft.App/sandboxGroups`, `Microsoft.App/sandboxGroups/vnetConnections` |
| **ADC data plane** | `management.{region}.azuredevcompute.io` | Individual sandboxes, disk images, snapshots, volumes, ports, egress policies |

This module **only manages the ARM control plane**. Individual sandbox CRUD
happens against the data plane (via the `aca` CLI, REST, or the ADC SDK) using
the `management_endpoint` output as the base URL.

## Usage

```hcl
module "sbx" {
  source = "github.com/Azure/terraform-provider-aca//modules/sandbox_groups"

  name              = "agent-sandboxes"
  resource_group_id = azurerm_resource_group.rg.id
  location          = "eastus2"

  default_cpu             = "2"
  default_memory          = "4Gi"
  default_disk            = "32Gi"
  max_sandbox_count       = 50
  default_timeout_seconds = 3600

  identity = {
    type = "SystemAssigned"
  }

  vnet_connections = {
    primary = { subnet_id = azurerm_subnet.sbx.id }
  }

  tags = { environment = "dev" }
}

output "adc_endpoint" {
  value = module.sbx.management_endpoint
}
```

## Variables

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Sandbox group name (2-64 chars, start with a letter). |
| `resource_group_id` | string | — | Resource ID of the parent resource group. |
| `location` | string | — | Azure region. |
| `default_cpu` | string | `"1"` | Default vCPU per sandbox (e.g. `"0.25"`, `"1"`, `"2"`). |
| `default_memory` | string | `"2Gi"` | Default memory per sandbox (`Gi` suffix). |
| `default_disk` | string | `"20Gi"` | Default ephemeral disk size. |
| `max_sandbox_count` | number | `50` | Concurrent sandbox cap. |
| `default_timeout_seconds` | number | `3600` | Auto-teardown timeout. |
| `network_config` | object | `null` | Inline network config (`public_network_access`, `subnet_id`). |
| `identity` | object | `null` | Managed identity (`type`, `identity_ids`). |
| `gateway_connections` | list(object) | `[]` | MCP server connections. |
| `vnet_connections` | map(object) | `{}` | Map of `vnetConnections` child resources keyed by name. |
| `tags` | map(string) | `{}` | Resource tags. |
| `api_version` | string | `"2026-02-01-preview"` | Preview API version. |

## Outputs

| Name | Description |
|---|---|
| `id` | Full ARM resource ID. |
| `name` | Resource name. |
| `management_endpoint` | ADC data-plane endpoint. |
| `provisioning_state` | Last reported provisioning state. |
| `principal_id` | System-assigned identity principal ID (when enabled). |
| `vnet_connection_ids` | Map of child VNet connection IDs. |

## RBAC

The caller deploying sandboxes against the data plane needs the
**Container Apps SandboxGroup Data Owner** role on the sandbox group (or its
parent resource group / subscription).

## API versions

Tracked in `docs/api-versions.json` under the `sandbox_groups` feature entry.
