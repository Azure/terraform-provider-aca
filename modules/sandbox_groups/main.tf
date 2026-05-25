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
  identity_block = var.identity == null ? null : {
    type        = var.identity.type
    identityIds = length(coalesce(var.identity.identity_ids, [])) > 0 ? var.identity.identity_ids : null
  }

  network_config_block = var.network_config == null ? null : {
    publicNetworkAccess = var.network_config.public_network_access
    subnetId            = var.network_config.subnet_id
  }

  gateway_connections_block = length(var.gateway_connections) == 0 ? null : [
    for gc in var.gateway_connections : merge(
      {
        resourceId = gc.resource_id
      },
      gc.mcp_runtime_url == null ? {} : { mcpRuntimeUrl = gc.mcp_runtime_url },
      gc.authentication == null ? {} : {
        authentication = merge(
          { type = gc.authentication.type },
          gc.authentication.identity_resource_id == null ? {} : { identityResourceId = gc.authentication.identity_resource_id }
        )
      }
    )
  ]

  properties = merge(
    {
      defaultCpu            = var.default_cpu
      defaultMemory         = var.default_memory
      defaultDisk           = var.default_disk
      maxSandboxCount       = var.max_sandbox_count
      defaultTimeoutSeconds = var.default_timeout_seconds
    },
    local.network_config_block == null ? {} : { networkConfig = local.network_config_block },
    local.gateway_connections_block == null ? {} : { gatewayConnections = local.gateway_connections_block },
  )

  body = merge(
    { properties = local.properties },
    local.identity_block == null ? {} : { identity = local.identity_block },
  )
}

resource "azapi_resource" "this" {
  type                      = "Microsoft.App/sandboxGroups@${var.api_version}"
  name                      = var.name
  location                  = var.location
  parent_id                 = var.resource_group_id
  schema_validation_enabled = false

  body = local.body

  tags = var.tags

  response_export_values = [
    "identity.principalId",
    "identity.tenantId",
    "properties.provisioningState",
    "properties.managementEndpoint",
  ]
}

# ---------------------------------------------------------------------------
# Child resource: vnet connections
# ---------------------------------------------------------------------------

resource "azapi_resource" "vnet_connection" {
  for_each = var.vnet_connections

  type                      = "Microsoft.App/sandboxGroups/vnetConnections@${var.api_version}"
  name                      = each.key
  parent_id                 = azapi_resource.this.id
  schema_validation_enabled = false

  body = {
    request = {
      location = var.location
      properties = {
        subnetId = each.value.subnet_id
      }
    }
  }
}
