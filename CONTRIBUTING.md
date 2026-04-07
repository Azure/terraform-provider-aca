# Contributing to Terraform Extension Layer for Azure Container Apps

Thank you for your interest in contributing! This document provides guidelines
for contributing to this project.

## Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- An Azure subscription with permissions to create Container Apps resources
- Azure CLI (`az`) logged in

### Development Setup

1. Clone the repository
2. Navigate to any example directory
3. Run `terraform init` to download providers
4. Run `terraform validate` to check configuration

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include Terraform version, provider versions, and full error output
- Provide a minimal reproduction example if possible

### Adding New Features

This module uses the **AzAPI overlay pattern** — features not yet supported by
AzureRM are implemented via `azapi_update_resource` overlays. When adding a new
AzAPI feature:

1. **Check the capability registry** (`internal/capability_registry.yaml`) to see
   if the feature is already tracked
2. **Add the feature flag** to the container app module's `feature_flags` variable
3. **Implement the AzAPI overlay** in `modules/container_app/azapi.tf` using a
   conditional `azapi_update_resource`
4. **Update the capability registry** with the new feature mapping
5. **Create or update an example** demonstrating the feature
6. **Add tests** in `tests/unit/`

### Adding New Examples

Each example should:

- Live in `examples/<example_name>/`
- Include a `main.tf`, `variables.tf`, `outputs.tf`, and `README.md`
- Use the root module as `source = "../../"` (or reference submodules directly)
- Pass `terraform validate` with no errors
- Include a README with a Mermaid architecture diagram

### Code Style

- Use 2-space indentation for HCL
- Follow [Terraform style conventions](https://developer.hashicorp.com/terraform/language/syntax/style)
- Use descriptive resource names (e.g., `azurerm_container_app.api` not `azurerm_container_app.this`)
- Comment non-obvious configuration choices

### Pull Request Process

1. Fork the repository and create a feature branch
2. Make your changes and ensure `terraform validate` passes on all affected examples
3. Run `terraform fmt -recursive` to format all files
4. Update documentation (README, example READMEs, CHANGELOG)
5. Open a PR with a clear description of what changed and why

## Architecture Decisions

- **AzureRM-first**: Base resources always use `azurerm_*` for stability
- **AzAPI for gaps only**: Only use AzAPI when AzureRM lacks support
- **Feature flags**: Preview features must be explicitly opted into
- **Brownfield-friendly**: Variable shapes mirror AzureRM resource arguments

See [architecture.md](architecture.md) for the full architecture reference.

## Automated Coverage Updates

This repo includes a GitHub Actions workflow (`.github/workflows/api-coverage.yml`)
that automatically checks for new ACA API versions every Sunday and triggers a
Copilot coding agent to analyze coverage gaps. See the workflow file for details.

## Code of Conduct

This project follows the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
