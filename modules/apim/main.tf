locals {
  # The llm-token-limit policy isn't available on the Consumption gateway, so
  # token caps switch on automatically when a classic or v2 tier is selected.
  token_limit_supported = !startswith(var.sku_name, "Consumption")
}

resource "azurerm_api_management" "this" {
  #checkov:skip=CKV_AZURE_107:The Consumption tier can't join a virtual network. Developer and Premium tiers can.
  #checkov:skip=CKV_AZURE_174:The gateway is the public entry point by design; every call requires a subscription key and is rate limited and quota capped.
  name                = "apim-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# The gateway reaches Azure OpenAI with its own managed identity. This is the
# only identity allowed to call the model.
resource "azurerm_role_assignment" "apim_openai_user" {
  scope                = var.openai_account_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    connection_string = var.application_insights_connection_string
  }
}

resource "azurerm_api_management_backend" "openai" {
  #checkov:skip=CKV_AZURE_215:False positive. The URL is computed from the account endpoint, which is always https://; "http" here is the protocol type (HTTP vs SOAP), not the scheme.
  name                = "azure-openai"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  protocol            = "http"
  url                 = "${trimsuffix(var.openai_endpoint, "/")}/openai"
}

resource "azurerm_api_management_api" "openai" {
  name                  = "azure-openai"
  api_management_name   = azurerm_api_management.this.name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "Azure OpenAI"
  path                  = "openai"
  protocols             = ["https"]
  subscription_required = true

  # Callers send their gateway key in the same header the OpenAI SDKs use, so
  # the stock SDK works against the gateway without modification.
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

resource "azurerm_api_management_api_operation" "chat_completions" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "Create chat completion"
  method              = "POST"
  url_template        = "/deployments/{deployment-id}/chat/completions"

  template_parameter {
    name     = "deployment-id"
    required = true
    type     = "string"
  }
}

# Request telemetry to Application Insights: status, latency, and backend
# timing for every call. Payloads aren't logged, and caller IPs aren't kept.
resource "azurerm_api_management_api_diagnostic" "openai" {
  identifier               = "applicationinsights"
  api_name                 = azurerm_api_management_api.openai.name
  api_management_name      = azurerm_api_management.this.name
  resource_group_name      = var.resource_group_name
  api_management_logger_id = azurerm_api_management_logger.appinsights.id
  sampling_percentage      = 100
  always_log_errors        = true
  log_client_ip            = false
  verbosity                = "information"
}

resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  xml_content         = file("${path.module}/policies/api.xml")

  depends_on = [azurerm_api_management_backend.openai]
}

# The product is where consumption limits live: the quota policy is only
# valid at product scope, and every caller subscribes through it.
resource "azurerm_api_management_product" "lab" {
  product_id            = "agent-lab"
  api_management_name   = azurerm_api_management.this.name
  resource_group_name   = var.resource_group_name
  display_name          = "Agent lab"
  description           = "Rate-limited, quota-capped access to the lab model deployment."
  subscription_required = true
  approval_required     = false
  subscriptions_limit   = 5
  published             = true
}

resource "azurerm_api_management_product_api" "lab_openai" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.lab.product_id
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
}

resource "azurerm_api_management_product_policy" "lab" {
  product_id          = azurerm_api_management_product.lab.product_id
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policies/product.xml.tftpl", {
    rate_limit_calls    = var.rate_limit_calls_per_minute
    daily_quota_calls   = var.daily_quota_calls
    token_limit_enabled = local.token_limit_supported
    tokens_per_minute   = var.tokens_per_minute
    daily_token_quota   = var.daily_token_quota
  })
}

resource "azurerm_api_management_subscription" "app" {
  display_name        = "agent-app"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  product_id          = azurerm_api_management_product.lab.id
  state               = "active"
  allow_tracing       = false
}
