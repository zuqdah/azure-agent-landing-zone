output "id" {
  description = "Resource ID of the API Management instance."
  value       = azurerm_api_management.this.id
}

output "gateway_url" {
  description = "Base URL of the gateway."
  value       = azurerm_api_management.this.gateway_url
}

output "app_subscription_key" {
  description = "Primary key of the app's product subscription."
  value       = azurerm_api_management_subscription.app.primary_key
  sensitive   = true
}

output "token_limit_enabled" {
  description = "Whether the llm-token-limit policy is active on this tier."
  value       = local.token_limit_supported
}
