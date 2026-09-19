output "id" {
  description = "Resource ID of the vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Name of the vault."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "Data-plane URI of the vault."
  value       = azurerm_key_vault.this.vault_uri
}
