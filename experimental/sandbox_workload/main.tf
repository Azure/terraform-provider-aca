locals {
  preservation_notice = "Terraform destroy removes only this companion's state hooks. It never issues data-plane delete commands; Sandboxes, disks, snapshots, volumes, files, and secrets are preserved."

  disk_name         = coalesce(var.disk_name, "tf-${substr(split("@sha256:", var.image_reference)[1], 0, 24)}")
  image_fingerprint = substr(sha256(var.image_reference), 0, 32)

  sensitive_environment_shape = {
    for name in sort(nonsensitive(keys(var.sensitive_environment))) :
    name => "__sensitive_value_excluded__"
  }

  normalized_configuration = {
    sandbox_group_id = var.sandbox_group_id
    image_reference  = var.image_reference
    disk_name        = local.disk_name
    selector_labels  = var.selector_labels
    resources        = var.resources
    entrypoint       = var.entrypoint
    command          = var.command
    environment      = var.environment
    sensitive_environment = {
      keys     = local.sensitive_environment_shape
      revision = var.sensitive_environment_revision
    }
    lifecycle_policy = var.lifecycle_policy
    egress_policy    = var.egress_policy
    ports            = var.ports
    primary_port     = var.primary_port_name
    mcp_path         = var.mcp_path
    health_path      = var.health_path
  }

  config_fingerprint = substr(sha256(jsonencode(local.normalized_configuration)), 0, 32)
  selector_labels = merge(var.selector_labels, {
    aca_config_fingerprint = local.config_fingerprint
  })

  workflow_fingerprint = sha256(join("", [
    filesha256("${path.module}/scripts/AcaSandbox.Common.ps1"),
    filesha256("${path.module}/scripts/Invoke-AcaSandboxWorkload.ps1"),
    filesha256("${path.module}/scripts/Get-AcaSandboxWorkload.ps1"),
  ]))

  workload_configuration = {
    aca_cli_path                        = var.aca_cli_path
    subscription_id                     = var.subscription_id
    resource_group_name                 = var.resource_group_name
    location                            = var.location
    sandbox_group_name                  = var.sandbox_group_name
    sandbox_group_id                    = var.sandbox_group_id
    image_reference                     = var.image_reference
    image_fingerprint                   = local.image_fingerprint
    disk_name                           = local.disk_name
    disk_import_identity                = var.disk_import_identity
    allow_registry_fallback             = var.allow_registry_token_fallback
    registry_name                       = var.registry_name
    selector_labels                     = local.selector_labels
    resources                           = var.resources
    entrypoint                          = var.entrypoint
    command                             = var.command
    environment                         = var.environment
    lifecycle_policy                    = var.lifecycle_policy
    egress_policy                       = var.egress_policy
    ports                               = var.ports
    primary_port_name                   = var.primary_port_name
    mcp_path                            = var.mcp_path
    health_path                         = var.health_path
    config_fingerprint                  = local.config_fingerprint
    disk_ready_timeout_seconds          = var.disk_ready_timeout_seconds
    registry_auth_retry_timeout_seconds = var.registry_auth_retry_timeout_seconds
  }
}

resource "terraform_data" "workload" {
  input = {
    preservation_notice = local.preservation_notice
    sandbox_group_id    = var.sandbox_group_id
    sandbox_group_name  = var.sandbox_group_name
    disk_name           = local.disk_name
    config_fingerprint  = local.config_fingerprint
  }

  triggers_replace = {
    sandbox_group_id     = var.sandbox_group_id
    image_reference      = var.image_reference
    config_fingerprint   = local.config_fingerprint
    workflow_fingerprint = local.workflow_fingerprint
  }

  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "& '${abspath("${path.module}/scripts/Invoke-AcaSandboxWorkload.ps1")}'"

    environment = {
      ACA_SANDBOX_WORKLOAD_CONFIG_JSON      = jsonencode(local.workload_configuration)
      ACA_SANDBOX_WORKLOAD_ENVIRONMENT_JSON = jsonencode(merge(var.environment, var.sensitive_environment))
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.ports), var.primary_port_name)
      error_message = "primary_port_name must identify an entry in ports."
    }

    precondition {
      condition     = !contains(keys(var.selector_labels), "aca_config_fingerprint")
      error_message = "selector_labels must not define the reserved aca_config_fingerprint label."
    }

    precondition {
      condition = length(setintersection(
        toset(keys(var.environment)),
        toset(nonsensitive(keys(var.sensitive_environment)))
      )) == 0
      error_message = "The same environment variable name cannot appear in both environment and sensitive_environment."
    }

    precondition {
      condition     = !var.allow_registry_token_fallback || var.registry_name != null
      error_message = "registry_name is required when allow_registry_token_fallback is true."
    }
  }
}

data "external" "workload" {
  program = [
    "pwsh",
    "-NoProfile",
    "-NonInteractive",
    "-File",
    abspath("${path.module}/scripts/Get-AcaSandboxWorkload.ps1"),
  ]

  query = {
    aca_cli_path         = var.aca_cli_path
    subscription_id      = var.subscription_id
    resource_group_name  = var.resource_group_name
    location             = var.location
    sandbox_group_name   = var.sandbox_group_name
    disk_name            = local.disk_name
    image_fingerprint    = local.image_fingerprint
    selector_labels_json = jsonencode(local.selector_labels)
    ports_json           = jsonencode(var.ports)
    primary_port_name    = var.primary_port_name
    mcp_path             = var.mcp_path
    health_path          = var.health_path
    config_fingerprint   = local.config_fingerprint
  }

  depends_on = [terraform_data.workload]
}
