terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # Bootstrap runs once, locally, as a subscription Owner. Its state stays
  # local (and out of git); it holds no secrets, only resource IDs.
}

provider "azurerm" {
  # Register exactly the resource providers the lab uses. The pipeline
  # identity has no rights to do this itself.
  resource_providers_to_register = [
    "Microsoft.ApiManagement",
    "Microsoft.App",
    "Microsoft.CognitiveServices",
    "Microsoft.Consumption",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
  ]

  # The state account has shared keys disabled, so data-plane calls must use
  # Entra ID.
  storage_use_azuread = true

  features {}
}

provider "azuread" {}
