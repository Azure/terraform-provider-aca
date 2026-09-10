# Container App Environment

Uses AzureRM for standard Container App Environments and a dedicated AzAPI
resource for Express environments. Optional AzAPI overlays remain available for
other features not yet exposed by AzureRM.

## Design Principles

* **1:1 variable mapping** – every `azurerm_container_app_environment` argument is exposed as a module variable with the same name and type, making brownfield migration straightforward.
* **Feature flags** – preview capabilities (e.g. `peer_authentication`) are toggled via `feature_flags` and implemented as conditional `azapi_update_resource` resources.
* **Provider overrides** – once a preview feature lands in AzureRM GA you can set `provider_overrides = { peer_authentication = "azurerm" }` to skip the AzAPI resource.
* **Express path** – `environment_mode = "Express"` creates
  `Microsoft.App/managedEnvironments@2026-03-02-preview` directly through AzAPI.

## Usage

```hcl
module "container_app_environment" {
  source = "./modules/container_app_environment"

  name                = "my-cae"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  log_analytics_workspace_id     = azurerm_log_analytics_workspace.example.id
  infrastructure_subnet_id       = azurerm_subnet.example.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true

  workload_profile = [
    {
      name                  = "gpu"
      workload_profile_type = "NC24-A100"
      minimum_count         = 0
      maximum_count         = 3
    },
  ]

  feature_flags = {
    peer_authentication = true
  }

  tags = {
    environment = "dev"
  }
}
```

## Express

```hcl
module "express_environment" {
  source = "./modules/container_app_environment"

  name                = "my-express"
  resource_group_name = azurerm_resource_group.example.name
  location            = "swedencentral"
  environment_mode    = "Express"
}
```

Existing callers can continue using
`feature_flags = { express_mode = true }` as a compatibility alias. Express
rejects workload profiles, internal load balancing, zone redundancy, mTLS,
peer authentication, and premium ingress.

## Outputs

| Name | Description |
|------|-------------|
| `id` | The resource ID of the Container App Environment |
| `name` | The name of the Container App Environment |
| `default_domain` | The default domain of the environment |
| `static_ip_address` | The static IP address assigned to the environment |
| `docker_bridge_cidr` | Docker bridge CIDR |
| `platform_reserved_cidr` | Platform reserved CIDR |
| `platform_reserved_dns_ip_address` | Platform reserved DNS IP address |
| `environment_mode` | Resolved environment mode |
