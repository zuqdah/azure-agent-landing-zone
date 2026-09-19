output "app_url" {
  description = "Public URL of the sample agent API."
  value       = module.app.url
}

output "gateway_url" {
  description = "API Management gateway URL."
  value       = module.apim.gateway_url
}

output "apim_sku_name" {
  description = "API Management tier in use."
  value       = var.apim_sku_name
}

output "token_limit_enabled" {
  description = "Whether the llm-token-limit policy is active."
  value       = module.apim.token_limit_enabled
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint. Reachable only with an Entra ID token from an authorized identity."
  value       = module.openai.endpoint
}

output "key_vault_name" {
  description = "Key Vault holding the app's gateway key."
  value       = module.keyvault.name
}
