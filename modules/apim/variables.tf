variable "name" {
  description = "Globally unique name suffix; the instance is named apim-<name>."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "sku_name" {
  description = "Tier and capacity. Consumption_0 costs nothing at lab volumes; Developer_1 enables token limits but bills hourly and takes 30-45 minutes to create."
  type        = string
  default     = "Consumption_0"

  validation {
    condition     = contains(["Consumption_0", "Developer_1", "BasicV2_1", "StandardV2_1"], var.sku_name)
    error_message = "Use Consumption_0, Developer_1, BasicV2_1, or StandardV2_1."
  }
}

variable "publisher_name" {
  description = "Organization name shown in API Management."
  type        = string
}

variable "publisher_email" {
  description = "Contact address for API Management system notifications."
  type        = string
}

variable "openai_account_id" {
  description = "Resource ID of the Azure OpenAI account the gateway fronts."
  type        = string
}

variable "openai_endpoint" {
  description = "Endpoint of the Azure OpenAI account."
  type        = string
}

variable "application_insights_id" {
  description = "Resource ID of Application Insights for gateway telemetry."
  type        = string
}

variable "application_insights_connection_string" {
  description = "Connection string for Application Insights."
  type        = string
  sensitive   = true
}

variable "rate_limit_calls_per_minute" {
  description = "Maximum calls per subscription per minute."
  type        = number
  default     = 10
}

variable "daily_quota_calls" {
  description = "Maximum calls per subscription per day."
  type        = number
  default     = 200
}

variable "tokens_per_minute" {
  description = "Token rate limit per subscription. Applied only on tiers that support llm-token-limit."
  type        = number
  default     = 2000
}

variable "daily_token_quota" {
  description = "Daily token quota per subscription. Applied only on tiers that support llm-token-limit."
  type        = number
  default     = 100000
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
