---
page_title: "aca_sandbox Resource"
description: |-
  Manages an individual ACA Sandbox data-plane resource.
---

# aca_sandbox

```hcl
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

resource "aca_sandbox" "example" {
  sandbox_group_id = module.sandbox_group.id
  location         = var.location
  name             = "example"

  source = {
    private_disk_image_id = aca_sandbox_disk_image.interpreter.id
  }

  resources = {
    cpu    = "2000m"
    memory = "4096Mi"
    disk   = "32Gi"
  }

  environment = {
    LOG_LEVEL = "info"
  }

  environment_wo = {
    API_TOKEN = var.api_token
  }
  environment_wo_version = 1

  auto_suspend = {
    enabled          = true
    interval_seconds = 600
    mode             = "Memory"
  }

  egress_policy = {
    default_action = "Deny"

    host_rules = [{
      pattern = "*.github.com"
      action  = "Allow"
    }]
  }

  ports = {
    web = {
      port            = 8080
      protocol        = "Http"
      activation_mode = "OnDemand"

      auth = {
        anonymous = false
        entra_id = {
          enabled = true
          emails  = ["developer@example.com"]
        }
      }
    }
  }
}
```

## Source

Configure exactly one:

- `source.public_disk_image`
- `source.private_disk_image_id`
- `source.preset`

`resources` is required for public/private disk sources and must be omitted for
a preset.

Snapshot restore is deferred to a later provider release.

## Update behavior

Updated in place:

- `auto_suspend`
- `egress_policy`
- `ports`
- `allow_resume_for_updates`
- `deletion_policy`

All other configured fields require replacement.

If the service rejects an egress or port update because the Sandbox is stopped,
the provider fails by default. Set `allow_resume_for_updates = true` to let
Terraform resume it, apply the update, and leave it running.

## Sensitive environment values

Use `environment_wo` for values that must not enter plan or state. Increment
`environment_wo_version` to replace the Sandbox when those values rotate.

The provider never copies service-returned environment values into state.

## Ports

Port entries are keyed by a Terraform logical name. The service response is
matched by unique port number and supplies computed `host_port` and `url`.

IP access-control rules support at most 10 rules and 10 CIDRs per rule.
Priorities must be unique from 0 through 1000, and CIDRs must be canonical
network addresses.

## Import

```shell
terraform import aca_sandbox.example "https://management.swedencentral.azuredevcompute.io/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/sandboxGroups/group/sandboxes/sandbox-id"
```

For objects created outside the provider:

- Use the Sandbox service ID as `name` when `tf_aca_name` is absent.
- Use decimal port numbers as map keys when importing existing ports.
- Configure environment values manually; they are intentionally not imported.
