---
page_title: "ACA Provider"
description: |-
  Native Terraform provider for Azure Container Apps Sandbox data-plane resources.
---

# ACA Provider

The ACA provider manages Sandbox data-plane resources through the regional
Azure Container Apps Sandbox REST endpoint.

It is designed to compose with AzureRM/AzAPI:

- Use AzureRM/AzAPI or this repository's modules for SandboxGroups, networking,
  identity, and role assignments.
- Use this provider for private disk images and individual Sandboxes.

## Example provider configuration

```hcl
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aca = {
      source = "Azure/aca"
    }
  }
}

provider "aca" {
  use_azure_cli = true
}
```

## Provider arguments

- `tenant_id` - Optional Entra tenant ID.
- `client_id` - Optional service principal or workload identity client ID.
- `client_secret` - Optional sensitive service principal secret.
- `client_certificate_path` - Optional PEM or PKCS#12 certificate path.
- `client_certificate_password` - Optional sensitive certificate password.
- `oidc_token_file_path` - Optional federated token file.
- `use_managed_identity` - Enables managed identity authentication.
- `managed_identity_client_id` - Optional user-assigned identity client ID.
- `use_azure_cli` - Enables Azure CLI authentication for local development.
- `authority_host` - Optional Entra authority override.
- `disable_instance_discovery` - Optional private/disconnected cloud setting.
- `token_scope` - Defaults to `https://dynamicsessions.io/.default`.
- `api_version` - Defaults to `2026-02-01-preview`.
- `allow_custom_endpoint` - Allows a host outside `azuredevcompute.io`; an
  explicit `token_scope` is also required.
- `user_agent` - Optional request user-agent suffix.

## Endpoint security

Resources normally configure `location`, and the provider derives
`https://management.{location}.azuredevcompute.io`.

An explicit endpoint outside `azuredevcompute.io` is rejected unless both
`allow_custom_endpoint = true` and a non-default `token_scope` are configured.
This prevents forwarding a Sandbox token to an arbitrary HTTPS host.

## Authentication precedence

The provider uses one explicit credential mode followed by optional managed
identity and Azure CLI credentials when enabled:

1. Client secret, certificate, or workload identity.
2. Managed identity when enabled.
3. Azure CLI when enabled.

No PowerShell credential is included.
