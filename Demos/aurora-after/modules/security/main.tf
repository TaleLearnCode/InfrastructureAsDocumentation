# module: app-tier-secrets
#
# Purpose: Provisions the Key Vault and access policies that hold secrets for
#          the private application tier.
#
# Scope:   Identity and secret material only. No networks, no compute. The
#          subnets this vault trusts are inputs, not resources.
#
# Opinionated defaults: purge protection on, soft delete at 90 days, TLS 1.2
#          minimum, network access denied until a caller names a subnet.

data "azurerm_client_config" "current" {}

locals {
  name_prefix = "aurora-${var.deployment_environment}-appsec"

  governance_tags = {
    owner       = var.owning_team
    environment = var.deployment_environment
    managed_by  = "terraform"
    boundary    = "security"
  }

  tags = merge(var.additional_tags, local.governance_tags)
}

resource "azurerm_resource_group" "app_tier_secrets" {
  name     = "${local.name_prefix}-rg"
  location = var.region
  tags     = local.tags
}

resource "azurerm_key_vault" "app_tier_secrets" {
  name                = "${local.name_prefix}-kv"
  location            = var.region
  resource_group_name = azurerm_resource_group.app_tier_secrets.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = local.tags

  # Purge protection cannot be disabled once enabled. That is the point: a
  # deleted production vault must be recoverable, and no incident-time decision
  # should be able to make it otherwise.
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  enable_rbac_authorization = false

  network_acls {
    # Deny by default. A caller that needs access declares the subnet.
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.network_access_subnet_ids
  }
}

# Application identities get read-only access to secrets. Nothing here can
# write, and nothing here can touch keys or certificates.
resource "azurerm_key_vault_access_policy" "app_tier_read" {
  count = length(var.authorized_principal_ids)

  key_vault_id = azurerm_key_vault.app_tier_secrets.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.authorized_principal_ids[count.index]

  secret_permissions = ["Get", "List"]
}
