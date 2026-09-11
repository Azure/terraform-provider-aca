---
page_title: "aca_sandbox_disk_image Resource"
description: |-
  Imports a container image into an ACA SandboxGroup as a private disk image.
---

# aca_sandbox_disk_image

Creates a private Sandbox disk image and waits for it to reach `Ready`.

```hcl
resource "aca_sandbox_disk_image" "interpreter" {
  sandbox_group_id = module.sandbox_group.id
  location         = var.location
  name             = "python-interpreter"
  base_image       = "${var.registry}/python@sha256:${var.digest}"

  managed_identity_client_id = data.azuread_service_principal.sandbox_group.client_id
}
```

Registry credential fallback:

```hcl
variable "registry_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

resource "aca_sandbox_disk_image" "interpreter" {
  sandbox_group_id = module.sandbox_group.id
  location         = var.location
  name             = "python-interpreter"
  base_image       = var.image

  registry_username = var.registry_username
  registry_token_wo = var.registry_token
}
```

`registry_token_wo` is write-only and is never stored in plan or state.
Changing it alone does not rebuild a completed disk image.

## Arguments

- `sandbox_group_id` - Required SandboxGroup ARM ID.
- Exactly one of `location` or `endpoint`.
- `name` - Required logical name, unique in the SandboxGroup.
- `base_image` - Required container image reference. Digest pinning is
  recommended.
- `entrypoint` - Optional image entrypoint.
- `command` - Optional image command.
- `labels` - Optional user labels.
- `managed_identity_client_id` - Optional managed identity application/client
  ID. This is required by the currently deployed `2026-02-01-preview`
  data-plane rollout.
- `managed_identity_resource_id` - SDK-compatible identity resource selector,
  including `system`, retained for service rollouts that accept
  `managedIdentityResourceId`.
- `registry_username` and `registry_token_wo` - Optional credential pair.
- `deletion_policy` - `Delete` by default or `Retain`.
- `timeouts.create` and `timeouts.delete` - Optional duration overrides.

All remote image configuration changes require replacement.

Configure only one managed identity argument. Managed identity and registry
credential authentication are mutually exclusive.

## Import

```shell
terraform import aca_sandbox_disk_image.example "https://management.swedencentral.azuredevcompute.io/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/sandboxGroups/group/diskimages/image-id"
```
