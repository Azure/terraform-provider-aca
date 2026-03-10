# Tests — Terraform ACA Extension Layer

## Test Strategy

### Unit Tests (terraform test)
HCL-native tests using `.tftest.hcl` files validate each submodule with plan-only assertions.

```bash
# Run all unit tests from the repo root
terraform test -test-directory=tests/unit

# Run a specific test
terraform test -test-directory=tests/unit -filter=tests/unit/app_basic.tftest.hcl
```

### Test Matrix

| Test | File | Module | Description | Status |
|------|------|--------|-------------|--------|
| env_basic | `unit/env_basic.tftest.hcl` | container_app_environment | Basic environment configuration | ✅ Written |
| env_networking | `unit/env_networking.tftest.hcl` | networking | VNet, subnet, NSG creation and delegation | ✅ Written |
| app_basic | `unit/app_basic.tftest.hcl` | container_app | Minimal container app | ✅ Written |
| app_ingress | `unit/app_ingress.tftest.hcl` | container_app | Ingress configuration | ✅ Written |
| app_preview_feature | `unit/app_preview_feature.tftest.hcl` | container_app | Feature flags and AzAPI overlay toggling | ✅ Written |
| job_scheduled | `unit/job_scheduled.tftest.hcl` | jobs | CRON-based scheduled job | ✅ Written |
| job_event_driven | `unit/job_event_driven.tftest.hcl` | jobs | Event-driven queue trigger with scaling rules | ✅ Written |
| observability | `unit/observability.tftest.hcl` | observability | Log Analytics workspace and Application Insights | ✅ Written |
| full_stack | — | root module | Deploy complete stack (networking + observability + env + app) | Planned |

### Integration Tests (terraform apply)
Full deployment tests should:
1. Deploy one of the examples (simple_app, enterprise_app, microservices, jobs)
2. Verify resources exist via Azure API
3. Test preview feature flags (AzAPI overlay)
4. Destroy all resources

```bash
# Run example (requires Azure credentials)
cd examples/simple_app
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
```

### Validate All Modules

```bash
# Validate all submodules
for dir in modules/*/; do
  echo "Validating $dir..."
  (cd "$dir" && terraform init -backend=false && terraform validate)
done

# Validate all examples
for dir in examples/*/; do
  echo "Validating $dir..."
  (cd "$dir" && terraform init -backend=false && terraform validate)
done
```
