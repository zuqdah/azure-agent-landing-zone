output "url" {
  description = "Public HTTPS URL of the app."
  value       = "https://${azurerm_container_app.this.ingress[0].fqdn}"
}

output "id" {
  description = "Resource ID of the container app."
  value       = azurerm_container_app.this.id
}
