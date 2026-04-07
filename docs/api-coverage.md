---
title: API Coverage
description: Feature coverage status across AzureRM and AzAPI
breadcrumbs:
  - title: Home
    url: /
  - title: API Coverage
    url: /api-coverage
prev_page:
  title: Feature Flags
  url: /feature-flags
next_page:
  title: Migration Guide
  url: /migration
---

<p class="lead">
The module tracks 19 ACA features and their provider coverage status. This page shows
which features use AzureRM, which use AzAPI, and which are on the roadmap.
</p>

## Current API Versions

| | Version |
|---|---|
| **Latest GA** | `2025-07-01` |
| **Latest Preview** | `2025-10-02-preview` |
| **AzureRM Provider** | >= 4.0.0 |
| **AzAPI Provider** | >= 2.0.0 |

## Feature Coverage Matrix

| Feature | AzureRM | Module | Provider | Example |
|---------|:-------:|:------:|----------|---------|
| Container Apps (basic) | ✅ | ✅ | `azurerm` | [Simple App]({{ '/examples/simple-app' | relative_url }}) |
| Managed Environments | ✅ | ✅ | `azurerm` | All examples |
| Ingress & TLS | ✅ | ✅ | `azurerm` | [Simple App]({{ '/examples/simple-app' | relative_url }}) |
| Dapr Integration | ✅ | ✅ | `azurerm` | [Microservices]({{ '/examples/microservices' | relative_url }}) |
| Workload Profiles | ✅ | ✅ | `azurerm` | [Enterprise App]({{ '/examples/enterprise-app' | relative_url }}) |
| Container App Jobs | ✅ | ✅ | `azurerm` | [Jobs]({{ '/examples/jobs' | relative_url }}) |
| Multiple Revisions | ✅ | ✅ | `azurerm` | [Blue/Green]({{ '/examples/blue-green' | relative_url }}) |
| Custom Domains | ✅ | ✅ | `azurerm` | [Custom Domains]({{ '/examples/custom-domains' | relative_url }}) |
| Managed Identity | ✅ | ✅ | `azurerm` | [Enterprise App]({{ '/examples/enterprise-app' | relative_url }}) |
| Storage Volumes | ✅ | ✅ | `azurerm` | [Storage]({{ '/examples/storage' | relative_url }}) |
| Sticky Sessions | ❌ | ✅ | `azapi` | [Sticky Sessions]({{ '/examples/sticky-sessions' | relative_url }}) |
| CORS Policies | ❌ | ✅ | `azapi` | [CORS API]({{ '/examples/cors-api' | relative_url }}) |
| Additional Port Mappings | ❌ | ✅ | `azapi` | [Additional Ports]({{ '/examples/additional-ports' | relative_url }}) |
| Custom Scale Rules | ⚠️ | ✅ | `azapi` | [Autoscaling]({{ '/examples/autoscaling' | relative_url }}) |
| Java Components | ❌ | ✅ | `azapi` | [Java Spring]({{ '/examples/java-spring' | relative_url }}) |
| Session Pools | ❌ | ✅ | `azapi` | [Sessions]({{ '/examples/sessions' | relative_url }}) |
| Init Containers | ⚠️ | ✅ | `azapi` | [Init Containers]({{ '/examples/init-containers' | relative_url }}) |
| Private Endpoints | ✅ | ✅ | `azurerm` | [Private Endpoint]({{ '/examples/private-endpoint' | relative_url }}) |
| Resiliency Policies | ❌ | 🔜 | — | Planned |

**Legend:** ✅ Supported · ⚠️ Partial · ❌ Not supported · 🔜 Planned

## Automated Coverage Updates

A [GitHub Actions workflow](https://github.com/Azure/terraform-provider-aca/blob/main/.github/workflows/api-coverage.yml)
runs every Sunday at 12:00 UTC to check for new API versions:

1. **Queries** the [Azure REST API specs](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/app/resource-manager/Microsoft.App/ContainerApps)
   for new GA and preview versions
2. **Compares** against the tracked versions in `docs/api-versions.json`
3. **Launches** a Copilot coding agent to analyze new API specs, add module coverage,
   create examples, and open a PR

This ensures the module stays current with Azure's API releases without manual intervention.

## API Version History

| GA Version | Key Additions |
|------------|---------------|
| `2025-07-01` | Latest GA |
| `2025-01-01` | Java components, session pools, additional ports |
| `2024-03-01` | Workload profiles improvements |
| `2023-05-01` | Jobs, init containers |
| `2022-10-01` | Dapr, custom domains, secrets |
| `2022-03-01` | Initial GA — basic container apps |
