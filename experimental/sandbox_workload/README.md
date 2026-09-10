# Experimental ACA Sandbox workload companion

> **Experimental:** this module wraps the ACA Sandbox **data plane** exposed by
> `aca 1.0.0-beta.1`. It is an imperative companion, not a stable declarative
> Terraform resource. CLI behavior and manifest fields may change without
> compatibility guarantees.

The module imports or reuses a disk from an immutable OCI image, selects or
creates a Sandbox using deterministic labels plus a configuration fingerprint,
validates its manifest, applies it, and resolves named port endpoints.

## Prerequisites

- Terraform 1.5 or newer.
- PowerShell 7 (`pwsh`) on Windows or another supported host.
- `aca 1.0.0-beta.1`.
- Existing ACA CLI authentication and Sandbox Group Data Owner access.
- A Sandbox Group whose identity can pull the immutable image when
  `disk_import_identity` is configured.

Verify authentication before Terraform:

```powershell
aca --version
aca auth status --subscription $env:AZURE_SUBSCRIPTION_ID
```

The module never runs `az login`, `aca auth login`, or any interactive login.

## Usage

```hcl
module "workload" {
  source = "../../experimental/sandbox_workload"

  subscription_id     = var.subscription_id
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sandbox_group_name  = module.sandbox_group.name
  sandbox_group_id    = module.sandbox_group.id

  image_reference = "contoso.azurecr.io/python-code@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  disk_name       = "python-code-v1"

  selector_labels = {
    application = "agent-tools"
    component   = "code-interpreter"
    version     = "v1"
  }

  resources = {
    cpu    = "2000m"
    memory = "4096Mi"
  }

  entrypoint = ["python", "/app/server.py"]

  environment = {
    MCP_HOST = "0.0.0.0"
    MCP_PORT = "9000"
  }

  sensitive_environment = {
    MCP_AUTH_TOKEN = var.mcp_auth_token
  }
  sensitive_environment_revision = "rotation-2026-09"

  lifecycle_policy = {
    auto_suspend_enabled = false
  }

  egress_policy = {
    default_action = "Deny"
    host_rules = [
      { pattern = "pypi.org", action = "Allow" }
    ]
  }

  ports = {
    mcp = {
      port      = 9000
      anonymous = true
    }
  }

  primary_port_name = "mcp"
}
```

The current manifest schema exposes `entrypoint` and a `cmd` array. The module's
`command` input maps to `cmd`; include command arguments in that same list.

## Determinism and sensitive values

Terraform derives the disk name, image fingerprint, normalized workload
configuration, script fingerprint, manifest ordering, and
`aca_config_fingerprint` label. Non-sensitive environment values affect the
fingerprint. Sensitive values do not: only their variable names and the caller
controlled `sensitive_environment_revision` are included.

Sensitive values travel from Terraform to PowerShell through the child process
environment, not command-line arguments. Because `aca sandbox apply` requires a
file, PowerShell creates a uniquely named manifest in Terraform's current
working directory, validates/applies it, and removes it in `finally`. Terraform
state can still contain sensitive input values; protect remote state with
encryption and strict access controls.

Managed-identity disk import is preferred. The ACR token fallback is disabled
by default and is attempted only after bounded retries for an
authentication-related import failure.
`aca 1.0.0-beta.1` accepts that token only as a process argument, so enabling
the fallback carries a documented local process-inspection risk.

## Preservation semantics

**Terraform destroy does not delete any Sandbox data-plane resource.** There is
no destroy provisioner and no delete command. Removing this module from state
preserves Sandboxes, disks, snapshots, volumes, files, and secrets. This notice
is also stored in `terraform_data.workload.input` and exposed as
`preservation_notice`.

The generated Sandbox manifest also hard-disables the platform auto-delete
policy. `lifecycle_policy.auto_delete_enabled = true` and nonzero auto-delete
intervals are rejected during planning.

Cleanup must be a separate, explicitly reviewed operator workflow. Destroying a
parent ARM Sandbox Group is outside this module and should be protected and
reviewed independently.
