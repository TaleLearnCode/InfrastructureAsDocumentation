# module: private-app-network
#
# Purpose: Provisions the isolated VNet topology for the private application
#          tier: virtual network, tiered subnets, and the security groups that
#          enforce the boundary between them.
#
# Scope:   Networking only. No compute, no identity, no observability. If a
#          resource here is not a VNet, subnet, NSG, route table, or peering,
#          it is in the wrong module.
#
# Consumers: modules/compute (app tier), modules/security (private endpoints),
#            modules/observability (flow logs).
#
# Owner:   Platform Engineering -- see var.owning_team for the accountable team.

locals {
  # Names encode purpose, not implementation. A reader should know what a
  # resource is FOR before reading a single attribute.
  name_prefix = "aurora-${var.deployment_environment}-appnet"

  governance_tags = {
    owner       = var.owning_team
    environment = var.deployment_environment
    managed_by  = "terraform"
    boundary    = "network"
  }

  tags = merge(var.additional_tags, local.governance_tags)
}

resource "azurerm_resource_group" "private_app_network" {
  name     = "${local.name_prefix}-rg"
  location = var.region
  tags     = local.tags
}

# The private application network. Named for what it is for -- a private
# network serving the application tier -- so that no future engineer mistakes
# it for the organization's primary routing VNet.
resource "azurerm_virtual_network" "private_app_network" {
  name                = "${local.name_prefix}-vnet"
  location            = var.region
  resource_group_name = azurerm_resource_group.private_app_network.name
  address_space       = var.network_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "app_tier" {
  name                 = "${local.name_prefix}-app-tier"
  resource_group_name  = azurerm_resource_group.private_app_network.name
  virtual_network_name = azurerm_virtual_network.private_app_network.name
  address_prefixes     = [var.app_tier_address_prefix]
}

resource "azurerm_subnet" "data_tier" {
  name                 = "${local.name_prefix}-data-tier"
  resource_group_name  = azurerm_resource_group.private_app_network.name
  virtual_network_name = azurerm_virtual_network.private_app_network.name
  address_prefixes     = [var.data_tier_address_prefix]

  # Storage reached over the service endpoint, never over the public internet.
  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "management" {
  name                 = "${local.name_prefix}-management"
  resource_group_name  = azurerm_resource_group.private_app_network.name
  virtual_network_name = azurerm_virtual_network.private_app_network.name
  address_prefixes     = [var.management_address_prefix]
}

# Application tier: HTTPS in from the load balancer, nothing else.
resource "azurerm_network_security_group" "app_tier_allow_https" {
  name                = "${local.name_prefix}-app-tier-allow-https"
  location            = var.region
  resource_group_name = azurerm_resource_group.private_app_network.name
  tags                = local.tags

  security_rule {
    name                       = "allow-https-from-load-balancer"
    description                = "The application tier terminates TLS at the load balancer only. Port 443 is the entire public surface of this tier."
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    description                = "Explicit deny. Azure's implicit deny is not documentation; this rule states the intent so a reviewer can see it."
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Data tier: reachable from the application tier, never from the internet.
resource "azurerm_network_security_group" "data_tier_deny_public" {
  name                = "${local.name_prefix}-data-tier-deny-public"
  location            = var.region
  resource_group_name = azurerm_resource_group.private_app_network.name
  tags                = local.tags

  security_rule {
    name                       = "allow-app-tier-to-database"
    description                = "Only the application tier may reach the database port. Any other source is an architecture violation, not a firewall exception."
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.app_tier_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    description                = "The data tier has no public ingress. This rule exists so the intent survives a future engineer who is tempted to 'just open it briefly'."
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# Management plane: corporate ranges only.
resource "azurerm_network_security_group" "management_corp_only" {
  name                = "${local.name_prefix}-management-corp-only"
  location            = var.region
  resource_group_name = azurerm_resource_group.private_app_network.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = var.management_source_ranges

    content {
      name                       = "allow-corp-ssh-${security_rule.key}"
      description                = "Administrative access originates from the corporate VPN concentrator ranges. Widening this list requires a security review."
      priority                   = 100 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "app_tier" {
  subnet_id                 = azurerm_subnet.app_tier.id
  network_security_group_id = azurerm_network_security_group.app_tier_allow_https.id
}

resource "azurerm_subnet_network_security_group_association" "data_tier" {
  subnet_id                 = azurerm_subnet.data_tier.id
  network_security_group_id = azurerm_network_security_group.data_tier_deny_public.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management_corp_only.id
}
