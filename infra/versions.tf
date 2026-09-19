terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }

  # Partial configuration. Storage account, container, and key are supplied
  # at init time (see the workflows and README), and access uses Entra ID
  # rather than storage account keys.
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  # The pipeline identity is scoped to a single resource group and can't
  # register resource providers. Registration is done once in bootstrap/.
  resource_provider_registrations = "none"

  features {
    # Soft-deleted resources hold their names and, for API Management,
    # would block a redeploy. Purge on destroy so teardown is complete.
    api_management {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}
