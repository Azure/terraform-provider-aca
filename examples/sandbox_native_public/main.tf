data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
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

data "aca_sandbox_public_disk_image" "ubuntu" {
  sandbox_group_id = module.sandbox_group.id
  location         = module.sandbox_group.location
  name             = "ubuntu"

  depends_on = [module.sandbox_group]
}

resource "aca_sandbox" "ubuntu" {
  sandbox_group_id = module.sandbox_group.id
  location         = module.sandbox_group.location
  name             = var.sandbox_name

  source = {
    public_disk_image = data.aca_sandbox_public_disk_image.ubuntu.name
  }

  resources = {
    cpu    = "1000m"
    memory = "2048Mi"
    disk   = "20Gi"
  }

  labels = {
    example = "sandbox-native-public"
    image   = "ubuntu"
  }

  entrypoint = ["/bin/sh", "-c"]
  command    = ["while true; do sleep 3600; done"]

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
