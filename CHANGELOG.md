# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Azure Container Apps Express environments and apps through dedicated AzAPI
  resources using the currently deployed `2026-03-02-preview` ARM contract.
- Explicit `environment_mode` with compatibility support for
  `feature_flags.express_mode`.
- Express support for HTTP/TCP probes, HTTP/CPU/memory scaling, CORS, IP
  restrictions, ephemeral storage, user-assigned identity, and outbound VNet
  subnets within current preview constraints.
- Minimal stable-shaped and rich-preview ACA Sandbox Group profiles, VNet connections,
  role assignments, and optional deletion locks.
- Experimental ACA CLI-backed Sandbox workload create-or-reuse companion with
  preservation-only destroy semantics.
- Express, Sandbox Group, and Python Sandbox code-interpreter examples.
- Native Go Terraform provider for Sandbox and private disk-image data-plane
  resources, including imports, updates, retention, polling, write-only
  credentials, and read-only data sources.
- Deployable native-provider examples for public Ubuntu Sandboxes and
  ACR-backed private disk images using repository-scoped credentials.
- Safe migration guidance for moving pre-existing Express state from the
  earlier AzureRM-plus-overlay implementation to the dedicated AzAPI resources.

### Changed

- API coverage tracks the published Microsoft.App `2026-07-01` specification
  separately from the currently registered Express and Sandbox runtime APIs.
- AzureRM compatibility is explicitly constrained to the supported 4.x
  provider line.
- Terraform tests now use provider mocks and root-relative module paths.
- Disk-image registry authentication accepts both SDK-style managed identity
  selectors and the newer client-ID contract, and handles computed write-only
  registry tokens correctly during planning.

## [0.1.0] - 2025-03-10

### Added

- Initial release of the Terraform Extension Layer for Azure Container Apps
- Core modules: `container_app`, `container_app_environment`, `jobs`, `networking`, `observability`
- AzAPI overlay pattern for features not yet in AzureRM (sticky sessions, additional ports, CORS, autoscaling rules, Java components, init containers)
- Capability registry (`internal/capability_registry.yaml`) mapping features to providers
- Migration guide and helper script for transitioning AzAPI features back to AzureRM
- 15 deployment-tested examples covering real-world ACA patterns:
  - `simple_app` — Minimal single container app with VNet and ingress
  - `enterprise_app` — VNet, mTLS, workload profiles, App Insights
  - `microservices` — Dapr-enabled service mesh (frontend/backend/worker)
  - `jobs` — CRON scheduled job and event-driven queue processor
  - `sessions` — Dynamic session pools (PythonLTS)
  - `storage` — Azure Files SMB mounts (read-write and read-only)
  - `sticky_sessions` — Session affinity via AzAPI feature flags
  - `private_endpoint` — VNet + ILB + workload profiles + private endpoint + private DNS
  - `custom_domains` — Conditional custom domain binding with certificates
  - `autoscaling` — HTTP and KEDA scale rules via AzAPI overlay
  - `additional_ports` — gRPC/TCP port mapping via AzAPI advanced ingress
  - `blue_green` — Multi-revision traffic splitting for blue/green deployments
  - `cors_api` — Frontend + API with CORS policy via AzAPI overlay
  - `java_spring` — Spring Cloud Eureka + Config Server via AzAPI Java components
  - `init_containers` — Init containers with shared EmptyDir volumes
- Unit tests using Terraform native test framework (`.tftest.hcl`)
- GitHub Actions workflow for automated API coverage updates
- Copilot coding agent prompt for feature gap analysis
- API version registry (`docs/api-versions.json`) tracking 19 ACA features
