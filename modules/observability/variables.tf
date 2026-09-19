variable "name" {
  description = "Workload name used to derive resource names."
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

variable "retention_in_days" {
  description = "Log retention. 30 days is the minimum for PerGB2018 and is included at no extra cost."
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. Ingestion stops for the day once reached."
  type        = number
  default     = 0.1
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
