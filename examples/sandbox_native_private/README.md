# Native provider Sandbox with a private disk image

This example creates an ACR, imports Azure Linux from MCR through an ARM action,
creates a repository-scoped read-only ACR token, and uses the native
`Azure/aca` provider to create a private disk image and a Sandbox. No ACA CLI,
PowerShell, Docker daemon, or local image-build provisioner is required.

The token password is passed through the provider's write-only
`registry_token_wo` argument and is not copied into the disk-image resource
state. The AzureRM token-password resource remains a sensitive credential
source in Terraform state.

Defaults:

- resource group: `tf-aca-21`
- region: `swedencentral`
- Sandbox Group: `aca-sbox-native-private`
- source image: `mcr.microsoft.com/azurelinux/base/core:3.0`

## Prerequisites

- Terraform 1.11 or newer.
- Azure CLI authenticated to the target subscription.
- The locally built `Azure/aca` provider while it remains unpublished.
- Permissions to create resource groups, ACR, ACR scope maps and tokens,
  Sandbox Groups, role assignments, private disk images, and Sandboxes.

Build and configure the provider as described in
[`../../provider/README.md`](../../provider/README.md), then deploy:

```powershell
terraform init
terraform plan -var "subscription_id=<subscription-id>" -out tfplan
terraform apply tfplan
```

The Sandbox, private disk image, and Sandbox Group are protected from Terraform
destroy. Remove the `prevent_destroy` lifecycle rules and disable the group
lock only when explicit cleanup is intended.
