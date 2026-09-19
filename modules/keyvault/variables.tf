variable "name" {
  description = "Globally unique name suffix; the vault is named kv-<name> (24 characters max)."
  type        = string

  validation {
    condition     = length("kv-${var.name}") <= 24
    error_message = "Key Vault names are limited to 24 characters."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant that authenticates requests to the vault."
  type        = string
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
