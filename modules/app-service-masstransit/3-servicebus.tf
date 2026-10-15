# ---------------------------------------------------------------------------
# Service Bus - the transport MassTransit runs over.
#
# There are no queues, topics or subscriptions here: MassTransit creates them
# when each app starts, from the consumers, sagas and message types it has
# registered. The Standard tier is needed for topics.
#
# Local (SAS key) authentication is disabled, so there's no connection string
# to leak: the only way in is an Entra access token for the app's identity.
# ---------------------------------------------------------------------------
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.name_prefix}-bus"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  local_auth_enabled  = false
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Data-plane role assignments.
#
# MassTransit deploys its own topology (it creates queues, topics and
# subscriptions on start-up, and the web app's temporary reply queue), which
# needs the Manage right - so each app is a Data Owner of the namespace.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "servicebus_owner" {
  for_each = local.apps

  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}
