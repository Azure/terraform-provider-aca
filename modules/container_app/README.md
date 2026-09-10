# Container App Module

Uses AzureRM for standard Container Apps, dedicated
`Microsoft.App/containerApps@2026-03-02-preview` AzAPI resources for Express apps, and
optional AzAPI overlays for other capabilities not yet available in AzureRM.

## Design Principles

- **1:1 variable mapping** – variables mirror the AzureRM resource arguments so existing brownfield configs can be migrated by simply moving values into the module call.
- **`type = any` for complex blocks** – keeps the module thin; no redundant nested object type definitions to maintain.
- **Feature flags** – toggle preview capabilities (e.g. additional port mappings, function-app kind, Dapr app-health) via `feature_flags`. Each flag creates a conditional `azapi_update_resource` that patches the deployed Container App.
- **Provider overrides** – skip the AzAPI patch for a given flag by setting `provider_overrides = { flag_name = "azurerm" }` once AzureRM catches up.

## Usage – Standard

```hcl
module "api" {
  source = "../../modules/container_app"

  name                         = "my-api"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template = {
    containers = [
      {
        name   = "api"
        image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
        cpu    = 0.25
        memory = "0.5Gi"
        env = [
          { name = "ENV_VAR", value = "hello" },
        ]
      }
    ]
    min_replicas = 1
    max_replicas = 3
  }

  ingress = {
    target_port      = 80
    external_enabled = true
    traffic_weight = [
      { percentage = 100, latest_revision = true }
    ]
  }

  tags = {
    environment = "dev"
  }
}
```

## Usage – Preview Features (AzAPI Overlay)

```hcl
module "api_preview" {
  source = "../../modules/container_app"

  name                         = "my-api-preview"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template = {
    containers = [
      {
        name   = "api"
        image  = "myregistry.azurecr.io/myapp:v2"
        cpu    = 0.5
        memory = "1Gi"
      }
    ]
    min_replicas = 1
    max_replicas = 5
  }

  ingress = {
    target_port      = 8080
    external_enabled = true
    traffic_weight = [
      { percentage = 100, latest_revision = true }
    ]
  }

  # Enable preview features
  feature_flags = {
    advanced_ingress = true
    kind_functionapp = true
  }

  additional_port_mappings = [
    { external = true, target_port = 8443, exposed_port = 443 },
  ]
}
```

## Usage – Express

Set `environment_mode = "Express"` and provide `location`. The module enforces
the current Express subset: one container, single revision, HTTP ingress,
manual secrets, user-assigned identity, HTTP/CPU/memory scaling, HTTP/TCP
probes, CORS/IP restrictions, and ephemeral storage. Volumes and volume mounts
are rejected because the Express service does not support them.

```hcl
module "express_app" {
  source = "../../modules/container_app"

  name                         = "express-api"
  location                     = "swedencentral"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.express_environment.id
  environment_mode             = "Express"
  revision_mode                = "Single"

  template = {
    containers = [{
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }]
  }

  ingress = {
    external_enabled = true
    target_port      = 80
    transport        = "http"
  }
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `name` | `string` | yes | Container App name |
| `location` | `string` | Express only | Azure region |
| `environment_mode` | `string` | no | Target environment mode |
| `resource_group_name` | `string` | yes | Resource group name |
| `container_app_environment_id` | `string` | yes | Environment ID |
| `revision_mode` | `string` | yes | `Single` or `Multiple` |
| `template` | `any` | yes | Template block (containers, replicas, etc.) |
| `workload_profile_name` | `string` | no | Workload profile to pin to |
| `tags` | `map(string)` | no | Resource tags |
| `ingress` | `any` | no | Ingress configuration |
| `dapr` | `any` | no | Dapr sidecar configuration |
| `identity` | `any` | no | Managed identity block |
| `registry` | `list(any)` | no | Registry auth blocks |
| `secret` | `list(any)` | no | Secret blocks |
| `feature_flags` | `object` | no | Toggle AzAPI overlay features |
| `provider_overrides` | `map(string)` | no | Override provider per feature flag |
| `additional_port_mappings` | `list(object)` | no | Extra port mappings (preview) |
| `outbound_vnet_subnet_id` | `string` | no | Immutable Express app-level outbound subnet |

## Outputs

| Name | Description |
|------|-------------|
| `id` | Container App resource ID |
| `name` | Container App name |
| `latest_revision_name` | Latest revision name |
| `latest_revision_fqdn` | Latest revision FQDN |
| `outbound_ip_addresses` | Outbound IP addresses |
| `custom_domain_verification_id` | Custom domain verification ID |
