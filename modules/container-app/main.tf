resource "azurerm_container_app_environment" "this" {
  name                = "cae-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Required in azurerm 5.x before a workspace can be attached.
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = var.tags
}

resource "azurerm_container_app" "this" {
  name                         = "ca-${var.name}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  # A reference, not a value: the platform resolves the secret from Key Vault
  # at runtime using the app's managed identity.
  secret {
    name                = "apim-key"
    key_vault_secret_id = var.apim_key_secret_id
    identity            = var.identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Scale to zero: no requests, no compute charges.
    min_replicas = 0
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "OPENAI_ENDPOINT"
        value = var.gateway_url
      }
      env {
        name  = "OPENAI_DEPLOYMENT"
        value = var.deployment_name
      }
      env {
        name  = "REASONING_EFFORT"
        value = var.reasoning_effort
      }
      env {
        name  = "MAX_OUTPUT_TOKENS"
        value = tostring(var.max_output_tokens)
      }
      env {
        name        = "OPENAI_API_KEY"
        secret_name = "apim-key"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 8000
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 8000
      }
    }

    http_scale_rule {
      name                = "http"
      concurrent_requests = "20"
    }
  }

  tags = var.tags
}
