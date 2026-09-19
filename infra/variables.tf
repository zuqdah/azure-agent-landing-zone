variable "resource_group_name" {
  description = "Existing resource group created by bootstrap/. Everything in this configuration deploys into it."
  type        = string
  default     = "rg-agentlz-lab"
}

variable "location" {
  description = "Region override. Defaults to the resource group's region."
  type        = string
  default     = null
}

variable "publisher_name" {
  description = "Organization name shown in API Management."
  type        = string
  default     = "Ziyad Uqdah Labs"
}

variable "publisher_email" {
  description = "Contact address for API Management system notifications."
  type        = string
}

variable "app_image" {
  description = "Container image for the sample agent API."
  type        = string
  default     = "ghcr.io/zuqdah/agent-lz-app:latest"
}

variable "apim_sku_name" {
  description = "Consumption_0 for day-to-day use. Switch to Developer_1 to demonstrate token limits, then switch back."
  type        = string
  default     = "Consumption_0"
}

variable "model_name" {
  description = "Model to deploy."
  type        = string
  default     = "gpt-5.4-mini"
}

variable "model_version" {
  description = "Model version to deploy."
  type        = string
  default     = "2026-03-17"
}

variable "model_deployment_sku" {
  description = "Deployment type. New pay-as-you-go subscriptions receive quota per model and type, so check az cognitiveservices usage list before changing it."
  type        = string
  default     = "DataZoneStandard"
}

variable "model_capacity_ktpm" {
  description = "Deployment capacity in thousands of tokens per minute."
  type        = number
  default     = 5
}

variable "reasoning_effort" {
  description = "Reasoning effort the app requests. \"none\" skips reasoning, so the whole token budget goes to the answer."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "low", "medium", "high"], var.reasoning_effort)
    error_message = "Use none, low, medium, or high."
  }
}

variable "rate_limit_calls_per_minute" {
  description = "Gateway burst limit per subscription."
  type        = number
  default     = 10
}

variable "daily_quota_calls" {
  description = "Gateway daily call quota per subscription."
  type        = number
  default     = 200
}

variable "max_output_tokens" {
  description = "Per-request ceiling on generated tokens, enforced by the app."
  type        = number
  default     = 300
}

variable "log_daily_quota_gb" {
  description = "Daily Log Analytics ingestion cap in GB."
  type        = number
  default     = 0.1
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}
