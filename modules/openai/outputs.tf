output "id" {
  description = "Resource ID of the Azure OpenAI account."
  value       = azurerm_cognitive_account.this.id
}

output "endpoint" {
  description = "Endpoint of the Azure OpenAI account."
  value       = azurerm_cognitive_account.this.endpoint
}

output "deployment_name" {
  description = "Name of the model deployment."
  value       = azurerm_cognitive_deployment.this.name
}
