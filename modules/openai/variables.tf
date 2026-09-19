variable "name" {
  description = "Globally unique name suffix; the account is named oai-<name>."
  type        = string
}

variable "location" {
  description = "Azure region. The model must be available here for the chosen deployment SKU."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "deployment_name" {
  description = "Name of the model deployment that callers address."
  type        = string
  default     = "chat"
}

variable "model_name" {
  description = "Model to deploy."
  type        = string
  default     = "gpt-4.1-mini"
}

variable "model_version" {
  description = "Model version to deploy."
  type        = string
  default     = "2025-04-14"
}

variable "deployment_sku" {
  description = "Deployment type. GlobalStandard is pay-per-token with no hourly charge."
  type        = string
  default     = "GlobalStandard"
}

variable "capacity_ktpm" {
  description = "Deployment capacity in thousands of tokens per minute."
  type        = number
  default     = 5

  validation {
    condition     = var.capacity_ktpm >= 1 && var.capacity_ktpm <= 50
    error_message = "Keep lab capacity between 1K and 50K tokens per minute."
  }
}

variable "public_network_access_enabled" {
  description = "Allow access over the public endpoint. Disable when private endpoints are added."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
