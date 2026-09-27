# module: app-tier-compute
#
# Purpose: Provisions the virtual machines that run the application tier.
#
# Scope:   Compute only. Networks are consumed, never created here: this module
#          takes a subnet ID as an input and has no opinion about how that
#          subnet was built.
#
# Opinionated defaults: no public IPs, no password authentication, managed
#          identity on by default. A caller who needs otherwise is making an
#          architectural decision and should say so in a review, not in a flag.

locals {
  name_prefix = "aurora-${var.deployment_environment}-app"

  governance_tags = {
    owner       = var.owning_team
    environment = var.deployment_environment
    managed_by  = "terraform"
    boundary    = "compute"
  }

  tags = merge(var.additional_tags, local.governance_tags)
}

resource "azurerm_resource_group" "app_tier_compute" {
  name     = "${local.name_prefix}-rg"
  location = var.region
  tags     = local.tags
}

# No public_ip_address_id here, and that absence is the point: the application
# tier is reachable only through the load balancer in the network boundary.
resource "azurerm_network_interface" "app_tier" {
  count               = var.instance_count
  name                = "${local.name_prefix}-nic-${count.index}"
  location            = var.region
  resource_group_name = azurerm_resource_group.app_tier_compute.name
  tags                = local.tags

  ip_configuration {
    name                          = "private"
    subnet_id                     = var.app_tier_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app_tier" {
  count               = var.instance_count
  name                = "${local.name_prefix}-${count.index}"
  location            = var.region
  resource_group_name = azurerm_resource_group.app_tier_compute.name
  size                = var.instance_size
  admin_username      = "auroraops"
  tags                = local.tags

  # Password authentication is disabled by policy, not by preference.
  disable_password_authentication = true

  admin_ssh_key {
    username   = "auroraops"
    public_key = var.admin_ssh_public_key
  }

  network_interface_ids = [azurerm_network_interface.app_tier[count.index].id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
