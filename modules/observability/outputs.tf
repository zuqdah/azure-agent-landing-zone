output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "application_insights_id" {
  description = "Resource ID of Application Insights."
  value       = azurerm_application_insights.this.id
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace GUID, used by the Log Analytics query API (distinct from the resource ID)."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
