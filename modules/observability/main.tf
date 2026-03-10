locals {
  log_analytics_workspace_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].id : var.existing_log_analytics_workspace_id
}

resource "azurerm_log_analytics_workspace" "this" {
  count = var.create_log_analytics_workspace ? 1 : 0

  name                = "${var.name_prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.existing_log_analytics_workspace_id == null || var.existing_log_analytics_workspace_id == ""
      error_message = "Cannot set existing_log_analytics_workspace_id when create_log_analytics_workspace is true. Set create_log_analytics_workspace = false to use an existing workspace."
    }
  }
}

resource "azurerm_application_insights" "this" {
  count = var.create_application_insights ? 1 : 0

  name                = "${var.name_prefix}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = local.log_analytics_workspace_id
  application_type    = var.application_insights_type
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = { for s in var.diagnostic_settings : s.name => s }

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = local.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = each.value.metric_categories
    content {
      category = metric.value
    }
  }
}
