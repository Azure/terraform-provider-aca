# ---------------------------------------------------------------------------
# Microsoft.App/sandboxGroups
#
# Sandbox groups are an ARM-managed control-plane resource that provisions a
# pool of disposable Linux VMs (sandboxes) on the ACA data plane. Individual
# sandbox CRUD happens against `management.{region}.azuredevcompute.io` — that
# data plane is NOT modeled in ARM and is therefore not managed by Terraform.
# Use the `management_endpoint` output to drive the data plane from your
# automation (CLI, SDK, REST).
# ---------------------------------------------------------------------------

locals {
  api_version = coalesce(var.api_version, "2026-02-01-preview")

  properties = jsondecode(
    var.api_profile == "stable" ? jsonencode(
      var.environment_id == null ? {} : {
        environmentId = var.environment_id
      }
      ) : jsonencode({
        defaultCpu            = var.default_cpu
        defaultMemory         = var.default_memory
        defaultDisk           = var.default_disk
        maxSandboxCount       = var.max_sandbox_count
        defaultTimeoutSeconds = var.default_timeout_seconds
    })
  )
}

resource "azapi_resource" "this" {
  type                      = "Microsoft.App/sandboxGroups@${local.api_version}"
  name                      = var.name
  location                  = var.location
  parent_id                 = var.resource_group_id
  schema_validation_enabled = false
  ignore_null_property      = true

  dynamic "identity" {
    for_each = var.api_profile == "rich_preview" && var.identity != null ? [var.identity] : []
    content {
      type         = identity.value.type
      identity_ids = length(identity.value.identity_ids) == 0 ? null : identity.value.identity_ids
    }
  }

  body = {
    properties = local.properties
  }

  tags = var.tags

  response_export_values = [
    "identity.principalId",
    "identity.tenantId",
    "properties.provisioningState",
    "properties.managementEndpoint",
    "properties.defaultDomain",
  ]

  lifecycle {
    precondition {
      condition     = var.api_profile == "rich_preview" || (var.identity == null && var.default_cpu == null && var.default_memory == null && var.default_disk == null && var.max_sandbox_count == null && var.default_timeout_seconds == null)
      error_message = "Managed identity and group resource defaults require api_profile = rich_preview."
    }

    precondition {
      condition     = var.api_profile == "stable" || var.environment_id == null
      error_message = "environment_id is available only with api_profile = stable."
    }

    precondition {
      condition     = var.environment_id == null || var.api_version != null
      error_message = "environment_id is not exposed by the default 2026-02-01-preview contract; set api_version explicitly to a registered API version that supports environmentId."
    }
  }
}

# ---------------------------------------------------------------------------
# Child resource: vnet connections
# ---------------------------------------------------------------------------

resource "azapi_resource" "vnet_connection" {
  for_each = var.vnet_connections

  type                      = "Microsoft.App/sandboxGroups/vnetConnections@${local.api_version}"
  name                      = each.key
  parent_id                 = azapi_resource.this.id
  location                  = var.location
  schema_validation_enabled = false
  ignore_casing             = true

  body = {
    properties = {
      subnetId = each.value.subnet_id
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  subscription_role_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions"
  sandbox_data_owner_role = "${local.subscription_role_scope}/c24cf47c-5077-412d-a19c-45202126392c"
  acr_pull_role           = "${local.subscription_role_scope}/7f951dda-4ed3-4680-a7ca-43fe172d538d"
}

resource "azurerm_role_assignment" "data_plane_operator" {
  for_each = var.data_plane_operators

  scope                            = azapi_resource.this.id
  role_definition_id               = local.sandbox_data_owner_role
  principal_id                     = each.value.principal_id
  principal_type                   = each.value.principal_type
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
}

resource "azurerm_role_assignment" "acr_pull" {
  for_each = var.acr_pull_assignments

  scope                            = each.value.scope
  role_definition_id               = local.acr_pull_role
  principal_id                     = coalesce(each.value.principal_id, try(azapi_resource.this.output.identity.principalId, null))
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check

  lifecycle {
    precondition {
      condition     = each.value.principal_id != null || try(azapi_resource.this.output.identity.principalId, null) != null
      error_message = "acr_pull_assignments requires a principal_id or a rich-preview Sandbox Group with a system-assigned identity."
    }
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock_enabled ? 1 : 0

  name       = var.lock_name
  scope      = azapi_resource.this.id
  lock_level = "CanNotDelete"
  notes      = "Protects the Sandbox Group and its data-plane resources from accidental ARM deletion."
}
