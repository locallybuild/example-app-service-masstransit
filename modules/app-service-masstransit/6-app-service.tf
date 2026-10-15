# ---------------------------------------------------------------------------
# App Service Plan - houses both App Services.
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

# ---------------------------------------------------------------------------
# The web app and the worker - the same image, configured alike apart from the
# ROLE app setting and the identity they run as:
#
#   * web    - the page where orders are placed. It publishes OrderSubmitted
#              and asks the saga for each order's status.
#   * worker - hosts the order saga (persisted in Redis) and the fulfilment
#              consumer. Always On keeps it running, so it's always listening
#              on its queues rather than only when its URL is visited.
#
# App Service exposes each app's identity to its container through the managed
# identity endpoint (the IDENTITY_ENDPOINT and IDENTITY_HEADER environment
# variables), which Azure.Identity calls for tokens for Service Bus and Redis.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "main" {
  for_each = local.apps

  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [each.value.id]
  }

  site_config {
    always_on                         = each.key == "worker"
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = local.image_name
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = merge({
    ROLE = each.key

    # App Service routes public traffic to the container on this port, and the
    # app binds to it (12-factor port binding).
    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)

    # Where MassTransit connects. There's no connection string: the namespace
    # only accepts Entra access tokens.
    SERVICEBUS_ENDPOINT = azurerm_servicebus_namespace.main.endpoint

    # Where to reach Redis over TLS. On Azure the SSL port is always 6380; on
    # Locally the cache is served on a dynamically-allocated port, so the app
    # reads it rather than assuming 6380.
    REDIS_HOST = azurerm_redis_cache.main.hostname
    REDIS_PORT = tostring(azurerm_redis_cache.main.ssl_port)

    # Selects which of the web app's identities the managed identity endpoint
    # issues a token for.
    AZURE_CLIENT_ID = each.value.client_id
    }, local.redis_entra ? {} : {
    # Only when signing in to Redis with a key. Without it, the app signs in to
    # Redis as its managed identity.
    REDIS_KEY = azurerm_redis_cache.main.primary_access_key
  })

  # The image must exist in the registry, and the identity must hold its role
  # and Redis access policy, before the app starts.
  depends_on = [
    terraform_data.import_image,
    azurerm_role_assignment.servicebus_owner,
    azurerm_redis_cache_access_policy_assignment.main,
  ]
}
