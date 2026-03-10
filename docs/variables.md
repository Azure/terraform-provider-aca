---
title: Variables
description: Complete variable reference for the root module
breadcrumbs:
  - title: Home
    url: /
  - title: Variables
    url: /variables
prev_page:
  title: Modules
  url: /modules
next_page:
  title: Feature Flags
  url: /feature-flags
---

<p class="lead">
The root module exposes a small set of top-level variables that control which sub-modules
are instantiated and how resources are configured. Variable shapes mirror AzureRM for
easy brownfield adoption.
</p>

## Required Variables

### `name`

Base name used for all resources (resource group, environment, apps).

```hcl
name = "my-aca-project"
```

| | |
|---|---|
| **Type** | `string` |
| **Required** | Yes |

---

### `resource_group_name`

The name of the Azure resource group to deploy into.

```hcl
resource_group_name = azurerm_resource_group.rg.name
```

| | |
|---|---|
| **Type** | `string` |
| **Required** | Yes |

---

### `location`

Azure region for all resources.

```hcl
location = "swedencentral"
```

| | |
|---|---|
| **Type** | `string` |
| **Required** | Yes |

---

## Optional Variables

### `networking`

When set, creates a VNet, subnet, and NSG for the environment. When `null` (default),
the environment runs without VNet integration.

```hcl
networking = {
  vnet_address_space        = ["10.0.0.0/16"]
  aca_subnet_address_prefix = "10.0.0.0/23"
}
```

| | |
|---|---|
| **Type** | `object` |
| **Default** | `null` |

| Attribute | Type | Description |
|-----------|------|-------------|
| `vnet_address_space` | `list(string)` | VNet CIDR blocks |
| `aca_subnet_address_prefix` | `string` | Subnet CIDR (minimum /23 for ACA) |
| `nsg_rules` | `list(object)` | Additional NSG security rules |

---

### `observability`

When set, creates a Log Analytics workspace and optionally Application Insights.

```hcl
observability = {
  log_analytics_retention_in_days = 60
  create_application_insights     = true
}
```

| | |
|---|---|
| **Type** | `object` |
| **Default** | `null` |

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_analytics_retention_in_days` | `number` | `30` | Retention period |
| `create_application_insights` | `bool` | `false` | Create App Insights resource |

---

### `environment`

Additional configuration for the Container App Environment.

```hcl
environment = {
  zone_redundancy_enabled         = true
  internal_load_balancer_enabled  = true
  workload_profiles = [{
    name                  = "Dedicated"
    workload_profile_type = "D4"
    minimum_count         = 1
    maximum_count         = 3
  }]
}
```

| | |
|---|---|
| **Type** | `object` |
| **Default** | `{}` |

---

### `container_apps`

Map of container apps to create. Each key becomes the app name suffix.

```hcl
container_apps = {
  api = {
    revision_mode = "Single"
    template = {
      containers = [{
        name   = "api"
        image  = "myacr.azurecr.io/api:v1"
        cpu    = 0.5
        memory = "1Gi"
      }]
      max_replicas = 10
      min_replicas = 1
    }
    ingress = {
      external_enabled = true
      target_port      = 8080
    }
  }
}
```

| | |
|---|---|
| **Type** | `map(object)` |
| **Default** | `{}` |

See the [container_app module]({{ '/modules' | relative_url }}#container_app) for all available attributes.

---

### `jobs`

Map of Container App Jobs to create.

```hcl
jobs = {
  cleanup = {
    trigger_type    = "Schedule"
    cron_expression = "0 2 * * *"
    template = {
      containers = [{
        name   = "cleanup"
        image  = "myacr.azurecr.io/cleanup:latest"
        cpu    = 0.25
        memory = "0.5Gi"
      }]
    }
  }
}
```

| | |
|---|---|
| **Type** | `map(object)` |
| **Default** | `{}` |

See the [jobs module]({{ '/modules' | relative_url }}#jobs) for all available attributes.
