# ACA Express Mode (AzAPI Overlay Feature)

Demonstrates **ACA Express**, the fully serverless mode of
`Microsoft.App/managedEnvironments`. Express environments are zero-touch:
no VNet, no workload profile, no Log Analytics workspace — the platform
provisions and manages all underlying infrastructure. The only ARM-level
difference vs. a standard managed environment is a single property:
`properties.environmentMode = "Express"`.

## Why an AzAPI overlay?

The `environmentMode` property is silently dropped by GA API versions
(`2024-03-01`, `2025-07-01`, ...). The portal uses preview API version
`2025-10-02-preview` to read and write it. AzureRM currently targets a GA
version, so the module sets `environmentMode = "Express"` via an
`azapi_update_resource` overlay on top of the AzureRM-created environment.

## The feature_flags pattern

Flip a single flag to opt in:

```hcl
module "aca" {
  source = "github.com/Azure/terraform-provider-aca"

  name                = "my-express"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "northcentralus"

  environment = {
    feature_flags = {
      express_mode = true
    }
  }

  # NOTE: deploy apps onto Express envs via azapi_resource directly,
  # not through the module's container_apps map (see "Why apps use raw AzAPI"
  # below).
}
```

Express environments are incompatible with VNet integration, workload profiles,
zone redundancy, internal load balancers, and Premium Ingress. The module
enforces this via preconditions and will fail early with a clear error if you
mix them.

## Why apps use raw AzAPI

The Express RP rejects container apps that include a `probes` array
(`ExpressEnvironmentFeatureNotSupported: 'Probes' is not supported for container
app on express environments`). AzureRM's `azurerm_container_app` always
serializes a `probes` field (even when empty), so apps deployed via the module's
`container_apps` map will fail to create on an Express env.

This example therefore creates the sample app directly via
`azapi_resource "Microsoft.App/containerApps@2025-10-02-preview"`, omitting
`probes` from the body. The Express environment itself is still created and
managed by the module — only the app is bypassed.

Additionally, the Express mode flip is **asynchronous on the Azure side**: the
PATCH that switches `environmentMode` to `Express` returns success quickly, but
the underlying transition takes several minutes. If a container app create
races ahead, it can return `ManagedEnvironmentNotProvisioned`. In practice,
Terraform's resource ordering (the env precedes the app) plus AzAPI's own
provisioning poll handle this — but a re-apply may be needed if the timing is
unlucky.

## Resources Created

| Resource | Provider | Purpose |
|---|---|---|
| Resource Group | AzureRM | Container for all resources |
| Container App Environment | AzureRM (via module) | ACA control plane |
| Express overlay | **AzAPI** (via module) | Sets `environmentMode = "Express"` on the preview API |
| api app | **AzAPI** (raw) | Sample helloworld app (raw AzAPI to omit `probes`) |

## Usage

```bash
terraform init
terraform apply
```

Express-supported regions (as of writing): `westcentralus`, `eastasia`,
`northcentralus`, `eastus2euap`, `centraluseuap`. Defaults to
`northcentralus`.

## Variables

| Name | Description | Default |
|---|---|---|
| `name` | Base name for the deployment | `aca-express` |
| `resource_group_name` | Resource group name | `tf-aca-17` |
| `location` | Azure region (must support Express) | `northcentralus` |
| `tags` | Tags for all resources | `{ environment = "dev", ... }` |
| `container_image` | Container image for the sample app | `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` |

## Outputs

| Name | Description |
|---|---|
| `environment_id` | Container App Environment resource ID |
| `environment_default_domain` | Default domain of the Express environment |
| `environment_mode` | Confirmed environment mode (`Express`) |
| `api_app_url` | FQDN of the sample app |
