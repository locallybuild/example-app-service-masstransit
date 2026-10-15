terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "app-service-masstransit" {
  source = "../../modules/app-service-masstransit"

  name_prefix = "locally-example-masstransit"
  location    = "berlin"
  tags = {
    ProvisionedVia = "Terraform"
  }
}
