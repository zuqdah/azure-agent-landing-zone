data "azurerm_client_config" "current" {}

# Created by bootstrap/ and never destroyed by this configuration, so the
# pipeline's permissions and the budget survive every teardown.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Fresh names on every deploy. Soft-deleted Key Vaults and Azure OpenAI
# accounts reserve their names, so reusing names after a teardown would fail.
resource "random_string" "suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  name     = "agentlz-${random_string.suffix.result}"
  location = coalesce(var.location, data.azurerm_resource_group.lab.location)

  tags = merge(var.tags, {
    workload   = "agent-landing-zone"
    managed-by = "terraform"
    repo       = "github.com/zuqdah/azure-agent-landing-zone"
  })
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

module "observability" {
  source = "../modules/observability"

  name                = local.name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Model and gateway
# ---------------------------------------------------------------------------

module "openai" {
  source = "../modules/openai"

  name                = local.name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  model_name          = var.model_name
  model_version       = var.model_version
  deployment_sku      = var.model_deployment_sku
  capacity_ktpm       = var.model_capacity_ktpm
  tags                = local.tags
}

module "apim" {
  source = "../modules/apim"

  name                                   = local.name
  location                               = local.location
  resource_group_name                    = data.azurerm_resource_group.lab.name
  sku_name                               = var.apim_sku_name
  publisher_name                         = var.publisher_name
  publisher_email                        = var.publisher_email
  openai_account_id                      = module.openai.id
  openai_endpoint                        = module.openai.endpoint
  application_insights_id                = module.observability.application_insights_id
  application_insights_connection_string = module.observability.application_insights_connection_string
  rate_limit_calls_per_minute            = var.rate_limit_calls_per_minute
  daily_quota_calls                      = var.daily_quota_calls
  tags                                   = local.tags
}

# ---------------------------------------------------------------------------
# Identity and secrets
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${local.name}-app"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags
}

module "keyvault" {
  source = "../modules/keyvault"

  name                = replace(local.name, "-", "")
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}

# The deploying identity writes the gateway key; the app can only read it.
resource "azurerm_role_assignment" "deployer_kv_secrets_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# Role assignments are eventually consistent. Without a pause, the first
# secret write or the app's first Key Vault read can fail with a 403.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.deployer_kv_secrets_officer,
    azurerm_role_assignment.app_kv_secrets_user,
  ]
}

# Fixed at creation, so the expiry doesn't move on every plan.
resource "time_offset" "secret_expiry" {
  offset_days = 30
}

resource "azurerm_key_vault_secret" "apim_key" {
  name            = "apim-app-subscription-key"
  value           = module.apim.app_subscription_key
  key_vault_id    = module.keyvault.id
  content_type    = "API Management subscription key"
  expiration_date = time_offset.secret_expiry.rfc3339

  depends_on = [time_sleep.rbac_propagation]
}

# ---------------------------------------------------------------------------
# Workload
# ---------------------------------------------------------------------------

module "app" {
  source = "../modules/container-app"

  name                       = local.name
  location                   = local.location
  resource_group_name        = data.azurerm_resource_group.lab.name
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  identity_id                = azurerm_user_assigned_identity.app.id
  image                      = var.app_image
  gateway_url                = module.apim.gateway_url
  deployment_name            = module.openai.deployment_name
  reasoning_effort           = var.reasoning_effort
  apim_key_secret_id         = azurerm_key_vault_secret.apim_key.versionless_id
  max_output_tokens          = var.max_output_tokens
  tags                       = local.tags
}
