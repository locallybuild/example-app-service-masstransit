# ---------------------------------------------------------------------------
# Container Registry - for storing the Container Image within Locally.
#
# App Service pulls the image from here, the same as you'd host a private image
# on Azure. Both apps run the same image; the ROLE app setting picks whether a
# container runs as the web app or the worker.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.name_prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Import the app image from Docker Hub into the Locally ACR.
#
# Uses the Azure CLI to import the image, the same as you would against Azure,
# so nothing is built on this machine.
# ---------------------------------------------------------------------------
resource "terraform_data" "import_image" {
  triggers_replace = [
    var.container_image,
    local.image_name,
    azurerm_container_registry.main.login_server,
  ]

  provisioner "local-exec" {
    command = "az acr import --name ${azurerm_container_registry.main.name} --source ${var.container_image} --image ${local.image_name} --force"
  }
}
