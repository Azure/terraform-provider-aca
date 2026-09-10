# ACA Sandbox Group

Creates the ARM control plane for Azure Container Apps Sandboxes:

- `Microsoft.App/sandboxGroups`;
- a delegated subnet;
- `Microsoft.App/sandboxGroups/vnetConnections`;
- Container Apps SandboxGroup Data Owner for the Terraform caller;
- an optional `CanNotDelete` management lock.

The example defaults to the minimal `stable` profile on the currently
registered `2026-02-01-preview` API. It sends tags and VNet connections without
injecting group defaults or managed identity.

Set `api_profile = "rich_preview"` to opt into CPU, memory, disk, count,
timeout, and managed identity settings from the same preview contract:

```powershell
terraform apply -var 'api_profile=rich_preview'
```

Individual Sandboxes and disk images use the regional ACA data plane. See
`../sandbox_native_public` and `../sandbox_native_private` for first-class
Terraform resources. `../sandbox_code_interpreter` remains the preserved
experimental CLI-backed predecessor.

The subnet is delegated to `Microsoft.App/environments`; its delegation is
ignored for drift because the service can update delegation metadata.

## Deploy

```powershell
terraform init
terraform apply
```

Defaults: `swedencentral`, resource group `tf-aca-18`.
