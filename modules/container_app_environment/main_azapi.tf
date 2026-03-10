# ---------------------------------------------------------------------------
# AzAPI overlay resources for preview features
# ---------------------------------------------------------------------------

resource "azapi_update_resource" "peer_authentication" {
  count = (
    var.feature_flags.peer_authentication &&
    lookup(var.provider_overrides, "peer_authentication", "azapi") == "azapi"
  ) ? 1 : 0

  type        = "Microsoft.App/managedEnvironments@2024-10-02-preview"
  resource_id = azurerm_container_app_environment.this.id

  body = {
    properties = {
      peerAuthentication = {
        mtls = {
          enabled = true
        }
      }
    }
  }
}
