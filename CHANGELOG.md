# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
