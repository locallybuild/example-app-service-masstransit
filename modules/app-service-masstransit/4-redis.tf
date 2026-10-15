# ---------------------------------------------------------------------------
# Azure Cache for Redis - holds the saga's state, and the web app's list of
# recent orders.
#
# With redis_authentication = "entra", access keys are disabled and Microsoft
# Entra authentication is enabled, so each app signs in with a token for its
# managed identity instead of a key.
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache" "main" {
  name                               = "${var.name_prefix}-redis"
  resource_group_name                = azurerm_resource_group.main.name
  location                           = azurerm_resource_group.main.location
  capacity                           = 0
  family                             = "C"
  sku_name                           = "Basic"
  non_ssl_port_enabled               = false
  minimum_tls_version                = "1.2"
  access_keys_authentication_enabled = !local.redis_entra
  tags                               = var.tags

  redis_configuration {
    active_directory_authentication_enabled = local.redis_entra
  }
}

# ---------------------------------------------------------------------------
# Data access for Entra sign-in - lets each identity sign in and read and write
# keys. The alias is the username the identity signs in with, which
# Microsoft.Azure.StackExchangeRedis sets to the identity's object ID.
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache_access_policy_assignment" "main" {
  for_each = local.redis_entra ? local.apps : {}

  name               = "${each.key}-contributor"
  redis_cache_id     = azurerm_redis_cache.main.id
  access_policy_name = "Data Contributor"
  object_id          = each.value.principal_id
  object_id_alias    = each.value.principal_id
}
