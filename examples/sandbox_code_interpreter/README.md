# ACA Sandbox Python code interpreter (experimental predecessor)

This example builds a small Python MCP image in ACR, pins it by digest, creates
a **rich-preview** Sandbox Group through `../../modules/sandbox_groups`, grants
the Terraform caller SandboxGroup Data Owner and the group identity AcrPull,
then invokes `../../experimental/sandbox_workload`.

For first-class Terraform data-plane resources without ACA CLI or PowerShell,
use `../sandbox_native_public` or `../sandbox_native_private`. This example is
kept as a migration and custom-image reference and is not modified in place
because its deployed reproduction resources are preservation-sensitive.

Defaults:

- resource group: `tf-aca-19`
- region: `swedencentral`
- naming prefix and Sandbox Group: `aca-sandbox-code`
- MCP/health port: `8080` (an example default, not a module assumption)
- tags: `environment=dev`, `managed_by=terraform`

## Prerequisites

- Terraform 1.5 or newer.
- Azure CLI authenticated non-interactively for the target subscription.
- PowerShell 7.
- `aca 1.0.0-beta.1`, already authenticated.
- Permissions to create the resource group, ACR, Sandbox Group, and role
  assignments.

Verify the existing sessions:

```powershell
az account show --subscription <subscription-id>
aca auth status --subscription <subscription-id>
```

No script performs interactive login. Supply the subscription:

```powershell
terraform init
terraform plan -var "subscription_id=<subscription-id>"
terraform apply -var "subscription_id=<subscription-id>"
```

The example uses `az acr build` from a Terraform `local-exec` provisioner
because the image context is local. The tag is derived from all source files,
and a following `external` data source resolves the registry digest. Only the
digest-pinned image is passed to the workload module.

The MCP endpoint requires the sensitive `mcp_auth_token` output as a bearer
token. `/health` is intentionally unauthenticated.

The HTTP server runs separately from executed code. Each execution is launched
under the unprivileged `interpreter` UID with resource limits, bounded output,
and a seccomp filter that prevents descendants from escaping the execution
process group. The bearer token is not present in the child environment and is
not readable through the server process.

## Preservation

The experimental workload companion has no destroy provisioner and never calls
a Sandbox, disk, snapshot, volume, file, or secret delete command. Destroying
or removing that module preserves its data-plane resources. The Sandbox Group
is separately protected by a management lock, but deletion of parent ARM
infrastructure remains an independent operation that must be reviewed.
