data "azurerm_client_config" "current" {}

locals {
  registry_name = "acasbox${substr(md5("${var.subscription_id}-${var.resource_group_name}"), 0, 12)}"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "this" {
  name                          = local.registry_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azapi_resource_action" "import_image" {
  type        = "Microsoft.ContainerRegistry/registries@2025-11-01"
  resource_id = azurerm_container_registry.this.id
  action      = "importImage"
  method      = "POST"
  when        = "apply"

  body = {
    source = {
      registryUri = "mcr.microsoft.com"
      sourceImage = var.source_image
    }
    targetTags = [var.target_image]
    mode       = "Force"
  }
}

module "sandbox_group" {
  source = "../../modules/sandbox_groups"

  name              = var.sandbox_group_name
  resource_group_id = azurerm_resource_group.this.id
  location          = azurerm_resource_group.this.location
  api_profile       = "rich_preview"

  default_cpu             = "1"
  default_memory          = "2Gi"
  default_disk            = "20Gi"
  max_sandbox_count       = 5
  default_timeout_seconds = 3600

  data_plane_operators = {
    terraform_caller = {
      principal_id   = data.azurerm_client_config.current.object_id
      principal_type = "User"
    }
  }

  lock_enabled = true
  tags         = var.tags
}

resource "azurerm_container_registry_scope_map" "sandbox_pull" {
  name                    = "sandbox-pull"
  container_registry_name = azurerm_container_registry.this.name
  resource_group_name     = azurerm_resource_group.this.name
  description             = "Read-only access to the image imported for the native Sandbox example."
  actions = [
    "repositories/samples/azurelinux/content/read",
    "repositories/samples/azurelinux/metadata/read",
  ]
}

resource "azurerm_container_registry_token" "sandbox_pull" {
  name                    = "sandbox-pull"
  container_registry_name = azurerm_container_registry.this.name
  resource_group_name     = azurerm_resource_group.this.name
  scope_map_id            = azurerm_container_registry_scope_map.sandbox_pull.id
  enabled                 = true
}

resource "azurerm_container_registry_token_password" "sandbox_pull" {
  container_registry_token_id = azurerm_container_registry_token.sandbox_pull.id

  password1 {}
}

resource "aca_sandbox_disk_image" "azurelinux" {
  sandbox_group_id = module.sandbox_group.id
  location         = module.sandbox_group.location
  name             = "azurelinux-3"
  base_image       = "${azurerm_container_registry.this.login_server}/${var.target_image}"

  registry_username = azurerm_container_registry_token.sandbox_pull.name
  registry_token_wo = azurerm_container_registry_token_password.sandbox_pull.password1[0].value
  entrypoint        = ["/bin/sh", "-c"]
  command           = ["while true; do sleep 3600; done"]

  labels = {
    example = "sandbox-native-private"
    image   = "azurelinux"
  }

  deletion_policy = "Delete"

  timeouts = {
    create = "30m"
    delete = "15m"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azapi_resource_action.import_image,
    azurerm_container_registry_token_password.sandbox_pull,
    module.sandbox_group,
  ]
}

resource "aca_sandbox" "azurelinux" {
  sandbox_group_id = module.sandbox_group.id
  location         = module.sandbox_group.location
  name             = var.sandbox_name

  source = {
    private_disk_image_id = aca_sandbox_disk_image.azurelinux.id
  }

  resources = {
    cpu    = "1000m"
    memory = "2048Mi"
    disk   = "20Gi"
  }

  labels = {
    example = "sandbox-native-private"
    image   = "azurelinux"
  }

  auto_suspend = {
    enabled          = true
    interval_seconds = 600
    mode             = "Memory"
  }

  egress_policy = {
    default_action = "Deny"
  }

  deletion_policy = "Delete"

  timeouts = {
    create = "20m"
    delete = "10m"
  }

  lifecycle {
    prevent_destroy = true
  }
}
