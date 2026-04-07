---
title: Modules
description: Reference documentation for each sub-module in the ACA Extension Layer
breadcrumbs:
  - title: Home
    url: /
  - title: Modules
    url: /modules
prev_page:
  title: Architecture
  url: /architecture
next_page:
  title: Variables
  url: /variables
---

<p class="lead">
The module is composed of five sub-modules, each responsible for a specific aspect of the
Azure Container Apps deployment. All sub-modules can be used independently or through the
root module.
</p>

## container_app_environment

<span class="badge badge-azurerm">AzureRM</span>

Creates and configures the Azure Container App Environment — the hosting platform for
container apps and jobs.

| Input | Type | Description |
|-------|------|-------------|
| `name` | `string` | Environment name |
| `resource_group_name` | `string` | Resource group to deploy into |
| `location` | `string` | Azure region |
| `subnet_id` | `string` | Optional — subnet for VNet integration |
| `log_analytics_workspace_id` | `string` | Log Analytics workspace ID |
| `internal_load_balancer_enabled` | `bool` | Enable internal-only load balancer |
| `zone_redundancy_enabled` | `bool` | Enable zone redundancy |
| `workload_profiles` | `list(object)` | Optional — workload profiles (D4, D8, etc.) |

| Output | Description |
|--------|-------------|
| `id` | The environment resource ID |
| `default_domain` | The default domain for apps in this environment |
| `static_ip_address` | The static IP of the environment |

---

## container_app

<span class="badge badge-both">AzureRM + AzAPI</span>

Creates a Container App with ingress, Dapr, secrets, and optional AzAPI overlays for
preview features.

| Input | Type | Description |
|-------|------|-------------|
| `name` | `string` | App name |
| `environment_id` | `string` | Container App Environment ID |
| `resource_group_name` | `string` | Resource group |
| `revision_mode` | `string` | `"Single"` or `"Multiple"` |
| `template` | `object` | Container template (containers, replicas, volumes) |
| `ingress` | `object` | Optional — ingress configuration |
| `dapr` | `object` | Optional — Dapr sidecar configuration |
| `secrets` | `list(object)` | Optional — secrets |
| `feature_flags` | `object` | Optional — enable AzAPI overlay features |
| `additional_port_mappings` | `list(object)` | Optional — additional TCP/gRPC ports (requires `advanced_ingress` flag) |

### Feature Flags

When `feature_flags` are set, the module applies `azapi_update_resource` overlays
after creating the base AzureRM resource:

| Flag | AzAPI Feature | API Version |
|------|---------------|-------------|
| `advanced_ingress` | Additional port mappings, sticky sessions | 2025-01-01 |
| `cors_policy` | CORS policy configuration | 2025-01-01 |
| `custom_scale_rules` | HTTP and KEDA autoscaling rules | 2025-01-01 |

---

## jobs

<span class="badge badge-both">AzureRM + AzAPI</span>

Creates Container App Jobs for scheduled (CRON) and event-driven (queue) workloads.

| Input | Type | Description |
|-------|------|-------------|
| `name` | `string` | Job name |
| `environment_id` | `string` | Container App Environment ID |
| `resource_group_name` | `string` | Resource group |
| `trigger_type` | `string` | `"Schedule"` or `"Event"` |
| `cron_expression` | `string` | CRON schedule (for Schedule trigger) |
| `template` | `object` | Container template |
| `scale_rules` | `list(object)` | Optional — event-driven scale rules |
| `retry_policy` | `object` | Optional — retry configuration |

---

## networking

<span class="badge badge-azurerm">AzureRM</span>

Creates VNet, subnet, and NSG for the Container App Environment with proper delegation
handling.

| Input | Type | Description |
|-------|------|-------------|
| `name` | `string` | Base name for resources |
| `resource_group_name` | `string` | Resource group |
| `location` | `string` | Azure region |
| `vnet_address_space` | `list(string)` | VNet address space |
| `aca_subnet_address_prefix` | `string` | Subnet CIDR (minimum /23) |
| `nsg_rules` | `list(object)` | Optional — additional NSG rules |

| Output | Description |
|--------|-------------|
| `vnet_id` | VNet resource ID |
| `subnet_id` | Subnet resource ID |
| `nsg_id` | NSG resource ID |

<div class="callout callout-warning">
  <div class="callout-title">Important: Subnet Delegation</div>
  The subnet uses <code>ignore_changes = [delegation]</code> because ACA manages its own
  delegation during environment provisioning. Do not set delegation manually for
  consumption-only environments.
</div>

---

## observability

<span class="badge badge-azurerm">AzureRM</span>

Creates Log Analytics workspace and optionally Application Insights for monitoring.

| Input | Type | Description |
|-------|------|-------------|
| `name` | `string` | Base name for resources |
| `resource_group_name` | `string` | Resource group |
| `location` | `string` | Azure region |
| `retention_in_days` | `number` | Log retention period (default: 30) |
| `create_application_insights` | `bool` | Whether to create App Insights (default: false) |

| Output | Description |
|--------|-------------|
| `log_analytics_workspace_id` | Workspace resource ID |
| `application_insights_connection_string` | App Insights connection string (if created) |
| `application_insights_instrumentation_key` | App Insights instrumentation key (if created) |
