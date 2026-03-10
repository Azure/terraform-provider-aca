---
title: Feature Flags
description: How to enable AzAPI-backed preview features via feature flags
breadcrumbs:
  - title: Home
    url: /
  - title: Feature Flags
    url: /feature-flags
prev_page:
  title: Variables
  url: /variables
next_page:
  title: API Coverage
  url: /api-coverage
---

<p class="lead">
Feature flags are the opt-in mechanism for AzAPI-backed capabilities. When a flag is
enabled, the module creates an <code>azapi_update_resource</code> overlay on top of the base
AzureRM resource to add the missing properties.
</p>

## How Feature Flags Work

```hcl
container_apps = {
  api = {
    revision_mode = "Single"
    template = {
      containers = [{
        name   = "api"
        image  = "myacr.azurecr.io/api:v1"
        cpu    = 0.25
        memory = "0.5Gi"
      }]
    }

    # Enable AzAPI features
    feature_flags = {
      advanced_ingress   = true   # Additional ports, sticky sessions
      cors_policy        = true   # CORS configuration
      custom_scale_rules = true   # HTTP + KEDA scaling
    }

    # These fields are only used when the corresponding flag is set
    additional_port_mappings = [{
      external     = false
      target_port  = 9090
      exposed_port = 9090
    }]
  }
}
```

<div class="callout callout-tip">
  <div class="callout-title">Tip</div>
  Feature flags are designed to be <strong>removable</strong>. When AzureRM adds native support
  for a feature, you remove the flag, delete the overlay from state, and the base AzureRM
  resource takes over. See the <a href="/migration">Migration Guide</a>.
</div>

## Available Feature Flags

### `advanced_ingress`

Enables additional port mappings and session affinity (sticky sessions) via AzAPI overlay.

| | |
|---|---|
| **Provider** | AzAPI |
| **API Version** | `2025-01-01` |
| **AzureRM Support** | ❌ Not supported |

**Unlocks:**
- `additional_port_mappings` — expose gRPC, metrics, or other TCP ports alongside the main HTTP port
- `sticky_sessions` — session affinity mode (`sticky` or `none`)

**Example:**

```hcl
feature_flags = {
  advanced_ingress = true
}

additional_port_mappings = [
  {
    external     = false
    target_port  = 9090
    exposed_port = 9090
  }
]
```

See: [Additional Ports example]({{ '/examples/additional-ports' | relative_url }}),
[Sticky Sessions example]({{ '/examples/sticky-sessions' | relative_url }})

---

### `cors_policy`

Enables Cross-Origin Resource Sharing (CORS) policy configuration via AzAPI overlay.

| | |
|---|---|
| **Provider** | AzAPI |
| **API Version** | `2025-01-01` |
| **AzureRM Support** | ❌ Not supported |

**Unlocks:**
- `cors_policy.allowed_origins` — list of allowed origins
- `cors_policy.allowed_methods` — allowed HTTP methods
- `cors_policy.allowed_headers` — allowed request headers
- `cors_policy.max_age` — preflight cache duration in seconds

**Example:**

```hcl
feature_flags = {
  cors_policy = true
}

cors_policy = {
  allowed_origins = ["https://frontend.example.com"]
  allowed_methods = ["GET", "POST", "PUT", "DELETE"]
  allowed_headers = ["Content-Type", "Authorization"]
  max_age         = 3600
}
```

See: [CORS API example]({{ '/examples/cors-api' | relative_url }})

---

### `custom_scale_rules`

Enables HTTP-based and KEDA-based autoscaling rules via AzAPI overlay.

| | |
|---|---|
| **Provider** | AzAPI |
| **API Version** | `2025-01-01` |
| **AzureRM Support** | ⚠️ Partial (basic HTTP only) |

**Unlocks:**
- Custom HTTP scaling rules with detailed thresholds
- KEDA-based scaling with any supported scaler (Azure Queue, Kafka, etc.)

**Example:**

```hcl
feature_flags = {
  custom_scale_rules = true
}

custom_scale_rules = [
  {
    name = "http-scaling"
    type = "http"
    metadata = {
      concurrentRequests = "50"
    }
  },
  {
    name = "queue-scaling"
    type = "azure-queue"
    metadata = {
      queueName    = "work-items"
      queueLength  = "10"
      connectionFromEnv = "QUEUE_CONNECTION"
    }
  }
]
```

See: [Autoscaling example]({{ '/examples/autoscaling' | relative_url }})

## Feature Lifecycle

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Azure API adds  │───▶│  Module adds      │───▶│  AzureRM adds   │
│  new feature     │    │  AzAPI overlay    │    │  native support │
│                  │    │  + feature flag   │    │                 │
└─────────────────┘    └──────────────────┘    └────────┬────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  Migration:      │
                                               │  Remove flag,    │
                                               │  state rm overlay│
                                               │  AzureRM takes   │
                                               │  over natively   │
                                               └─────────────────┘
```
