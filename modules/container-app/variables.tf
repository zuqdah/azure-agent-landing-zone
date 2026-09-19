variable "name" {
  description = "Name suffix; resources are named cae-<name> and ca-<name>."
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

variable "log_analytics_workspace_id" {
  description = "Workspace that receives container console and system logs."
  type        = string
}

variable "identity_id" {
  description = "Resource ID of the user-assigned identity the app runs as."
  type        = string
}

variable "image" {
  description = "Container image to run."
  type        = string
}

variable "gateway_url" {
  description = "API Management gateway URL the app sends model requests to."
  type        = string
}

variable "deployment_name" {
  description = "Model deployment name to request."
  type        = string
}

variable "openai_api_version" {
  description = "Azure OpenAI data-plane API version."
  type        = string
}

variable "apim_key_secret_id" {
  description = "Versionless Key Vault secret ID holding the app's gateway key."
  type        = string
}

variable "max_output_tokens" {
  description = "Per-request ceiling on generated tokens, enforced by the app."
  type        = number
  default     = 300
}

variable "max_replicas" {
  description = "Upper bound on replicas."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
