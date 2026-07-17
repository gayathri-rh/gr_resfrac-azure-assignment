terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

   backend "azurerm" {
    resource_group_name  = "rg-resfracassign-dev"
    storage_account_name = "saresfracassigndev"
    container_name        = "tfstate"
    key                    = "resfrac.tfstate"
  }
}

provider "azurerm" {
  features {}
}
