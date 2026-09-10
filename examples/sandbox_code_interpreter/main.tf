data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "mcp_auth_token" {
  length  = 48
  special = false
}

locals {
  registry_name = substr(
    replace("${var.name_prefix}${random_string.suffix.result}", "-", ""),
    0,
    50
  )
  image_repository = "python-code-interpreter"
  source_hash = sha256(join("", [
    filesha256("${path.module}/src/.dockerignore"),
    filesha256("${path.module}/src/Dockerfile"),
    filesha256("${path.module}/src/executor.py"),
    filesha256("${path.module}/src/requirements.txt"),
    filesha256("${path.module}/src/server.py"),
  ]))
  image_tag = "tf-${substr(local.source_hash, 0, 16)}"
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

resource "terraform_data" "image_build" {
  triggers_replace = {
    registry_id = azurerm_container_registry.this.id
    source_hash = local.source_hash
    image_tag   = local.image_tag
    script_hash = filesha256("${path.module}/scripts/Build-AcrImage.ps1")
  }

  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "& '${abspath("${path.module}/scripts/Build-AcrImage.ps1")}'"

    environment = {
      ACA_EXAMPLE_IMAGE_BUILD_JSON = jsonencode({
        subscription_id  = var.subscription_id
        registry_name    = azurerm_container_registry.this.name
        repository       = local.image_repository
        tag              = local.image_tag
        source_directory = abspath("${path.module}/src")
      })
    }
  }
}

data "external" "image" {
  program = [
    "pwsh",
    "-NoProfile",
    "-NonInteractive",
    "-File",
    abspath("${path.module}/scripts/Get-AcrImageReference.ps1"),
  ]

  query = {
    subscription_id = var.subscription_id
    registry_name   = azurerm_container_registry.this.name
    login_server    = azurerm_container_registry.this.login_server
    repository      = local.image_repository
    tag             = local.image_tag
  }

  depends_on = [terraform_data.image_build]
}

module "sandbox_group" {
  source = "../../modules/sandbox_groups"

  name              = var.sandbox_group_name
  resource_group_id = azurerm_resource_group.this.id
  location          = azurerm_resource_group.this.location
  api_profile       = "rich_preview"

  default_cpu             = "2"
  default_memory          = "4Gi"
  default_disk            = "32Gi"
  max_sandbox_count       = 10
  default_timeout_seconds = 3600

  identity = {
    type = "SystemAssigned"
  }

  data_plane_operators = {
    terraform_caller = {
      principal_id = data.azurerm_client_config.current.object_id
    }
  }

  acr_pull_assignments = {
    interpreter_registry = {
      scope = azurerm_container_registry.this.id
    }
  }

  lock_enabled = true
  tags         = var.tags
}

module "code_interpreter" {
  source = "../../experimental/sandbox_workload"

  subscription_id     = var.subscription_id
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sandbox_group_name  = module.sandbox_group.name
  sandbox_group_id    = module.sandbox_group.id

  image_reference               = data.external.image.result.immutable_reference
  disk_name                     = "python-code-${local.image_tag}"
  disk_import_identity          = "system"
  allow_registry_token_fallback = var.allow_registry_token_fallback
  registry_name                 = azurerm_container_registry.this.name

  selector_labels = {
    application = var.name_prefix
    component   = "code-interpreter"
    version     = local.image_tag
  }

  resources = {
    cpu    = var.sandbox_cpu
    memory = var.sandbox_memory
  }

  entrypoint = ["python", "/app/server.py"]

  environment = {
    MCP_HOST = "0.0.0.0"
    MCP_PORT = tostring(var.sandbox_port)
  }

  sensitive_environment = {
    MCP_AUTH_TOKEN = random_password.mcp_auth_token.result
  }
  sensitive_environment_revision = var.mcp_token_revision

  lifecycle_policy = {
    auto_suspend_enabled = false
  }

  egress_policy = {
    default_action = "Deny"
    host_rules     = []
    rules          = []
  }

  ports = {
    mcp = {
      port      = var.sandbox_port
      anonymous = true
    }
  }

  primary_port_name = "mcp"
  mcp_path          = "/mcp"
  health_path       = "/health"

  depends_on = [module.sandbox_group]
}
