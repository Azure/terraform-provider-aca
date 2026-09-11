# Native provider Sandbox with a public image

This example creates a rich-preview Sandbox Group and uses the native
`Azure/aca` provider to create an Ubuntu Sandbox through the regional data
plane. It demonstrates public disk discovery, explicit resource sizing,
lifecycle policy, egress policy, provider-managed labels, and import URLs.

Defaults:

- resource group: `tf-aca-20`
- region: `swedencentral`
- Sandbox Group: `aca-sbox-native-public`
- public image: `ubuntu`

## Prerequisites

- Terraform 1.11 or newer.
- Azure CLI authenticated to the target subscription.
- The locally built `Azure/aca` provider while it remains unpublished.
- Permissions to create resource groups, Sandbox Groups, role assignments,
  and data-plane Sandboxes.

Build and configure the provider as described in
[`../../provider/README.md`](../../provider/README.md), then deploy:

```powershell
terraform init
terraform plan -var "subscription_id=<subscription-id>" -out tfplan
terraform apply tfplan
```

The Sandbox and Sandbox Group are protected from Terraform destroy. Remove the
`prevent_destroy` lifecycle rule and disable the group lock only when explicit
cleanup is intended.
