# ---------------------------------------------------------------------------
# User-Assigned Managed Identities - one per app.
#
# User-assigned (rather than system-assigned) identities exist before the web
# apps do, so their role assignments and Redis access policies are granted up
# front - each app has access from its very first request, rather than racing
# a grant that lands later.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "web" {
  name                = "${var.name_prefix}-web-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "worker" {
  name                = "${var.name_prefix}-worker-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}
