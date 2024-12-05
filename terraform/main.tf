provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azuread_application" "terraform_sp" {
  display_name = "terraform-sp"
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.terraform_sp.id
}

resource "azuread_service_principal_password" "sp_password" {
  service_principal_id = azuread_service_principal.sp.id
  end_date             = "2099-01-01T00:00:00Z"
}

resource "random_password" "sp_password" {
  length  = 16
  special = true
}

