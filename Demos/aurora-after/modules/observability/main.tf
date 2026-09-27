# module: network-flow-logs
#
# Purpose: Captures NSG flow logs for a network boundary and stores them for
#          the retention window Security requires.
#
# Scope:   Observability only. This is the module that owns the storage account
#          Aurora spent two years not understanding. It lives here because
#          capturing flow logs is an observability concern, and it is named for
#          the job it does so that no one has to ask what it is for again.
#
# Lifecycle: If flow log capture is retired, THIS MODULE is removed, and the
#          storage account goes with it. That is what a boundary buys you.

locals {
  name_prefix = "aurora-${var.deployment_environment}-flowlogs"

  governance_tags = {
    owner       = var.owning_team
    environment = var.deployment_environment
    managed_by  = "terraform"
    boundary    = "observability"
    purpose     = "nsg-flow-log-capture"
    retire_with = "flow-log-capture"
  }

  tags = merge(var.additional_tags, local.governance_tags)
}

resource "azurerm_resource_group" "network_flow_logs" {
  name     = "${local.name_prefix}-rg"
  location = var.region
  tags     = local.tags
}

resource "azurerm_network_watcher" "network_flow_logs" {
  name                = "${local.name_prefix}-watcher"
  location            = var.region
  resource_group_name = azurerm_resource_group.network_flow_logs.name
  tags                = local.tags
}

# The storage account whose purpose is now stated in three places: its name,
# its tags, and the module it lives in.
resource "azurerm_storage_account" "network_flow_logs" {
  name                     = "auroraflowlogs${var.deployment_environment}"
  location                 = var.region
  resource_group_name      = azurerm_resource_group.network_flow_logs.name
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = local.tags

  min_tls_version                 = var.minimum_tls_version
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
}

resource "azurerm_network_watcher_flow_log" "observed_boundary" {
  name                 = "${local.name_prefix}-capture"
  network_watcher_name = azurerm_network_watcher.network_flow_logs.name
  resource_group_name  = azurerm_resource_group.network_flow_logs.name
  tags                 = local.tags

  network_security_group_id = var.observed_network_security_group_id
  storage_account_id        = azurerm_storage_account.network_flow_logs.id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = var.retention_days
  }
}
