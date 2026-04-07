# Container App Jobs Module

Thin wrapper around `azurerm_container_app_job` with optional AzAPI overlay for
preview features.

## Usage

```hcl
module "cleanup_job" {
  source = "./modules/jobs"

  name                         = "cleanup-job"
  resource_group_name          = "my-rg"
  location                     = "eastus2"
  container_app_environment_id = module.environment.id
  replica_timeout_in_seconds   = 300
  trigger_type                 = "Schedule"

  template = {
    containers = [{
      name   = "cleanup"
      image  = "myacr.azurecr.io/cleanup:v1"
      cpu    = 0.25
      memory = "0.5Gi"
    }]
  }

  schedule_trigger_config = {
    cron_expression          = "0 0 * * *"
    parallelism              = 1
    replica_completion_count = 1
  }
}
```

## Preview Features

Enable preview features via `feature_flags`:

```hcl
module "event_job" {
  source = "./modules/jobs"
  # ...
  trigger_type = "Event"
  feature_flags = {
    event_trigger_advanced = true
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| id | Container App Job ID |
| name | Container App Job name |
| outbound_ip_addresses | Outbound IP addresses |
