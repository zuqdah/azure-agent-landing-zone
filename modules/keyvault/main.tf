resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV_AZURE_110:Purge protection off so nightly teardown can purge the vault. Production enables it.
  #checkov:skip=CKV_AZURE_42:Soft delete is on (7 days); the check also requires purge protection, skipped above.
  #checkov:skip=CKV_AZURE_109:Firewall defaults to Allow while public access is on; the vault is RBAC-only and holds one short-lived secret. Private endpoint is the production step.
  #checkov:skip=CKV_AZURE_189:Public endpoint kept for the lab (no VNet on the Consumption plan). Access is Entra ID RBAC only.
  #checkov:skip=CKV2_AZURE_32:Private endpoint omitted to keep the lab near zero cost.
  name                = "kv-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # Access is granted only through Azure RBAC role assignments; there are no
  # vault access policies to drift out of sync.
  rbac_authorization_enabled = true

  # Lab settings: the shortest soft-delete window, and purge protection off
  # so a teardown can purge the vault and nothing lingers or bills.
  # Production would enable purge protection.
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    bypass         = "AzureServices"
    default_action = var.public_network_access_enabled ? "Allow" : "Deny"
  }

  tags = var.tags
}
