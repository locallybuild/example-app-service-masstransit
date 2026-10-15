locals {
  # The tag the image is stored under inside the Locally Container Registry once
  # 5-container-registry.tf has imported it. It keeps the source image's version,
  # so changing var.container_image re-imports the image and rolls both App
  # Services onto it.
  image_version = element(split(":", var.container_image), length(split(":", var.container_image)) - 1)
  image_name    = "app-service-masstransit:${local.image_version}"

  # The port the container listens on inside App Service (the app's PORT, exposed
  # to App Service as WEBSITES_PORT). App Service terminates TLS at the platform
  # and routes public traffic to the container on this port.
  app_port = 8080

  # Both apps, keyed by their ROLE. Used wherever the two are configured alike.
  apps = {
    web    = azurerm_user_assigned_identity.web
    worker = azurerm_user_assigned_identity.worker
  }

  redis_entra = var.redis_authentication == "entra"
}
