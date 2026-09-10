# ACA Sandbox Data-Plane Provider

This directory contains the native Go Terraform provider for Azure Container
Apps Sandbox data-plane resources.

The provider is a preview implementation. It uses the regional Sandbox REST API
directly and does not require Python, PowerShell, ACA CLI, or Azure CLI when a
service principal, workload identity, or managed identity is configured.

## Implemented types

Managed resources:

- `aca_sandbox_disk_image`
- `aca_sandbox`

Data sources:

- `aca_sandbox_disk_image`
- `aca_sandbox_public_disk_image`
- `aca_sandbox`

SandboxGroup ARM resources, VNet connections, and role assignments remain
managed by AzureRM/AzAPI and the repository's existing modules.

## Requirements

- Go 1.25 or later to build the provider.
- Terraform 1.11 or later when using write-only arguments.
- A deployed ACA SandboxGroup.
- `Container Apps SandboxGroup Data Owner` access for the Terraform identity.

The default data-plane contract is:

- API version: `2026-02-01-preview`
- Token scope: `https://dynamicsessions.io/.default`
- Endpoint: `https://management.{location}.azuredevcompute.io`

## Build

```powershell
Set-Location provider
go test ./...
go build -o bin\terraform-provider-aca.exe .
```

For Linux or macOS:

```bash
cd provider
go test ./...
go build -o bin/terraform-provider-aca .
```

During incubation, use a Terraform CLI `dev_overrides` entry for
`registry.terraform.io/Azure/aca`. Public Terraform Registry publication is a
separate release decision because this repository also publishes Terraform
modules.

## Authentication

Supported authentication modes:

- Service principal client secret.
- Service principal certificate.
- Workload identity token file.
- System-assigned or user-assigned managed identity.
- Azure CLI as an explicitly enabled local-development fallback.

Standard `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
`AZURE_CLIENT_CERTIFICATE_PATH`, `AZURE_CLIENT_CERTIFICATE_PASSWORD`,
`AZURE_FEDERATED_TOKEN_FILE`, and `AZURE_AUTHORITY_HOST` environment variables
are supported.

Local Azure CLI example:

```hcl
provider "aca" {
  use_azure_cli = true
}
```

Managed identity example:

```hcl
provider "aca" {
  use_managed_identity       = true
  managed_identity_client_id = var.managed_identity_client_id
}
```

The provider builds an explicit Azure Identity credential chain. It does not
probe managed identity unless enabled and does not include Azure PowerShell.

## Basic example

```hcl
resource "aca_sandbox" "example" {
  sandbox_group_id = module.sandbox_group.id
  location         = var.location
  name             = "example"

  source = {
    public_disk_image = "ubuntu"
  }

  resources = {
    cpu    = "1000m"
    memory = "2048Mi"
  }

  auto_suspend = {
    enabled          = true
    interval_seconds = 300
    mode             = "Memory"
  }

  egress_policy = {
    default_action = "Deny"
  }
}
```

See `docs/` and `examples/` for the full schemas and migration instructions.

## Destroy behavior

Resources default to:

```hcl
deletion_policy = "Delete"
```

Use `Retain` to remove the object from Terraform state without deleting the
remote resource:

```hcl
deletion_policy = "Retain"
```

Apply a change to `deletion_policy` before running `terraform destroy`.
Terraform destroy uses the value already recorded in state. Use
`lifecycle.prevent_destroy` when destroy must be blocked entirely.

## Preview limitations

- The service API remains preview and is not available in every subscription or
  region.
- Snapshot restore, volumes, and secrets are not implemented.
- Exec, shell, and file operations are deliberately outside Terraform.
- Imported Sandboxes created by other tools use their service ID as the
  provider logical name unless they already contain `tf_aca_name`.
- Imported port map keys default to the decimal port number because the service
  does not retain Terraform logical keys.
- Environment values are not read back into Terraform state to avoid importing
  potentially sensitive values.
- Managed-identity ACR pulls are accepted by the provider but were rejected by
  the tested `2026-02-01-preview` Sweden Central rollout despite valid AcrPull
  assignments. The private-image sample uses scoped registry credentials.
