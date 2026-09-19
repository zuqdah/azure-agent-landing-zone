resource "azurerm_cognitive_account" "this" {
  #checkov:skip=CKV_AZURE_134:Public endpoint kept for the lab; key auth is disabled, so only Entra ID identities with a role can call it. A private endpoint is the production step.
  #checkov:skip=CKV_AZURE_247:Stricter than the check: outbound access is blocked entirely with no FQDN allowlist. The check only passes with a non-empty allowlist.
  #checkov:skip=CKV2_AZURE_22:Microsoft-managed encryption keys. Customer-managed keys need a purge-protected Key Vault, which conflicts with complete nightly teardown.
  name                = "oai-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"

  # A custom subdomain is required for Entra ID (token) authentication.
  custom_subdomain_name = "oai-${var.name}"

  # No API keys. Every caller must present an Entra ID token, so the only way
  # in is through an identity that has been granted a role on this account.
  local_auth_enabled = false

  public_network_access_enabled = var.public_network_access_enabled

  # Data exfiltration control: the account can't make outbound calls.
  outbound_network_access_restricted = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "this" {
  name                 = var.deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  # Capacity is measured in thousands of tokens per minute. Keeping it low is
  # a hard throughput ceiling enforced by Azure itself, independent of the
  # API Management policies in front of it.
  sku {
    name     = var.deployment_sku
    capacity = var.capacity_ktpm
  }
}
