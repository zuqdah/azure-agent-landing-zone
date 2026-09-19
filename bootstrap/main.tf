data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

locals {
  tags = {
    workload   = "agent-landing-zone"
    managed-by = "terraform"
    layer      = "bootstrap"
  }

  # GitHub issues OIDC subjects keyed on immutable owner and repository IDs,
  # e.g. repo:owner@123/name@456:environment:lab. A deleted-and-recreated
  # repository with the same name gets a new ID and can't sign in.
  github_owner   = split("/", var.github_repository)[0]
  github_repo    = split("/", var.github_repository)[1]
  subject_prefix = "repo:${local.github_owner}@${var.github_repository_owner_id}/${local.github_repo}@${var.github_repository_id}"

  # Roles the pipeline is allowed to grant, and nothing else.
  delegable_roles = [
    "Cognitive Services OpenAI User",
    "Key Vault Secrets Officer",
    "Key Vault Secrets User",
  ]
}

# ---------------------------------------------------------------------------
# Resource groups
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-agentlz-tfstate"
  location = var.location
  tags     = local.tags
}

# The only place the pipeline can deploy. It outlives every teardown, so
# the pipeline's permissions don't have to be re-granted each time.
resource "azurerm_resource_group" "lab" {
  name     = "rg-agentlz-lab"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Remote state
# ---------------------------------------------------------------------------

resource "random_string" "state" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "tfstate" {
  #checkov:skip=CKV_AZURE_59:GitHub-hosted runners reach state over the public endpoint from unpredictable IPs. Access requires an Entra ID identity with a data role; keys and SAS are disabled.
  #checkov:skip=CKV2_AZURE_33:Private endpoint omitted; see CKV_AZURE_59.
  #checkov:skip=CKV_AZURE_206:LRS is deliberate for lab state. Blob versioning protects against bad writes, and the state can be rebuilt.
  #checkov:skip=CKV_AZURE_33:No queues are used in this account.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed encryption keys; customer-managed keys aren't warranted for lab state.
  name                     = "stagentlz${random_string.state.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # No account keys, no SAS. Only Entra ID identities with a data role can
  # read or write state.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  # No anonymous blob access, ever.
  allow_nested_items_to_be_public = false

  blob_properties {
    # Every state write is recoverable.
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging would need a persistent Log Analytics workspace outside the nightly teardown; omitted to keep the lab at zero idle cost.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Lets whoever runs bootstrap also run infra/ locally.
resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------
# GitHub Actions identity (OIDC, no secrets)
# ---------------------------------------------------------------------------

resource "azuread_application" "deployer" {
  display_name = "gh-agentlz-deployer"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "deployer" {
  client_id = azuread_application.deployer.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# GitHub mints a short-lived token that names the repo and the job's
# context; Entra ID exchanges it only when the subject matches exactly.
resource "azuread_application_federated_identity_credential" "environment" {
  application_id = azuread_application.deployer.id
  display_name   = "github-${var.github_environment}-environment"
  description    = "Deploy and destroy jobs running in the ${var.github_environment} environment."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${local.subject_prefix}:environment:${var.github_environment}"
}

resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.deployer.id
  display_name   = "github-pull-request"
  description    = "Plan jobs on pull requests."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${local.subject_prefix}:pull_request"
}

# ---------------------------------------------------------------------------
# Pipeline permissions
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "deployer_contributor" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
}

data "azurerm_role_definition" "delegable" {
  for_each = toset(local.delegable_roles)
  name     = each.value
  scope    = data.azurerm_subscription.current.id
}

# The pipeline must create role assignments (the gateway's access to the
# model, the app's access to Key Vault). This condition means it can only
# ever grant or remove the three roles above, and only inside the lab group.
resource "azurerm_role_assignment" "deployer_rbac_admin" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition = templatefile("${path.module}/rbac-condition.tftpl", {
    role_ids = join(", ", [for r in data.azurerm_role_definition.delegable : basename(r.id)])
  })
}

resource "azurerm_role_assignment" "deployer_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
}

# Purging soft-deleted resources is a subscription-scoped action. This role
# carries only those actions, so teardown can be complete without granting
# the pipeline anything broader.
resource "azurerm_role_definition" "purger" {
  name        = "Agent LZ soft-delete purger"
  scope       = data.azurerm_subscription.current.id
  description = "Read and purge soft-deleted Key Vaults, Azure OpenAI accounts, and API Management instances."

  permissions {
    actions = var.purge_actions
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

resource "azurerm_role_assignment" "deployer_purger" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.purger.role_definition_resource_id
  principal_id       = azuread_service_principal.deployer.object_id
  principal_type     = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Cost guardrail
# ---------------------------------------------------------------------------

# Subscription-wide, so it covers anything created by hand as well. On a
# pay-as-you-go subscription a budget alerts; it doesn't stop spending. The
# scheduled teardown workflow is what actually bounds cost.
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-agentlz-monthly"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.monthly_budget_usd
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.budget_contact_emails
    }
  }

  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Forecasted"
    operator       = "GreaterThanOrEqualTo"
    contact_emails = var.budget_contact_emails
  }

  lifecycle {
    # The start date is fixed at creation; don't churn it every month.
    ignore_changes = [time_period]
  }
}
