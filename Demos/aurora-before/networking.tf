# networking.tf
# aurora platform
# owner: platform eng
# TODO: split this up before it gets out of hand -- 2022-08-19
# TODO: ^ still valid -- 2023-04-02
# TODO: ^^ -- 2024-11-15

terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "env" {
  type    = string
  default = "prod"
}

variable "region" {
  default = "eastus"
}

variable "rg_name" {
  type    = string
  default = "aurora-rg"
}

variable "vnet_cidr" {
  type    = list(string)
  default = ["10.40.0.0/16"]
}

variable "subnet_prefixes" {
  type    = list(string)
  default = ["10.40.1.0/24", "10.40.2.0/24", "10.40.3.0/24"]
}

variable "extra_subnet_prefix" {
  default = "10.40.9.0/24"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vm_count" {
  default = 3
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  default = "auroraadmin"
}

variable "admin_password" {
  default = "ChangeMe123!"
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "flow_log_retention" {
  default = 7
}

variable "kv_sku" {
  default = "standard"
}

variable "enable_peering" {
  default = true
}

variable "peer_vnet_id" {
  default = ""
}

variable "allowed_source" {
  default = "*"
}

variable "legacy_mode" {
  default = true
}

locals {
  prefix = "aurora-${var.env}"

  # NOTE: staging uses a different suffix, do not change
  suffix = var.env == "prod" ? "" : "-${var.env}"

  common_tags = merge(var.tags, {
    env = var.env
  })

  subnet_count = length(var.subnet_prefixes)

  is_legacy = var.legacy_mode == true && var.env == "prod"
}

resource "random_string" "sa" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.rg_name}-${var.env}"
  location = var.region
}

resource "azurerm_virtual_network" "main_vnet" {
  name                = "main-vnet-${var.env}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_cidr
  dns_servers         = ["10.40.0.4", "10.40.0.5"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [var.subnet_prefixes[0]]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [var.subnet_prefixes[1]]
}

resource "azurerm_subnet" "subnet3" {
  name                 = "subnet3"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [var.subnet_prefixes[2]]
}

# added for the thing in Q3
resource "azurerm_subnet" "subnet_new" {
  name                 = "subnet-new"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = [var.extra_subnet_prefix]

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_network_security_group" "sg1" {
  name                = "sg1-${var.env}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "sg2" {
  name                = "sg2-${var.env}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "sg3" {
  name                = "sg3"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "a1" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.sg1.id
}

resource "azurerm_subnet_network_security_group_association" "a2" {
  subnet_id                 = azurerm_subnet.subnet2.id
  network_security_group_id = azurerm_network_security_group.sg2.id
}

resource "azurerm_subnet_network_security_group_association" "a3" {
  subnet_id                 = azurerm_subnet.subnet3.id
  network_security_group_id = azurerm_network_security_group.sg3.id
}

resource "azurerm_network_security_rule" "rule_001" {
  name                        = "rule-001"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.40.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_002" {
  name                        = "rule-002"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_003" {
  name                        = "rule-003"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_004" {
  name                        = "rule-004"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "10.0.0.0/8"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_005" {
  name                        = "rule-005"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_006" {
  name                        = "rule-006"
  priority                    = 160
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6379"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_007" {
  name                        = "rule-007"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "192.168.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_008" {
  name                        = "rule-008"
  priority                    = 180
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9090"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_009" {
  name                        = "rule-009"
  priority                    = 190
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefix       = "10.40.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_010" {
  name                        = "rule-010"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_011" {
  name                        = "rule-011"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1521"
  source_address_prefix       = "10.40.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_012" {
  name                        = "rule-012"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "27017"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_013" {
  name                        = "rule-013"
  priority                    = 230
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5672"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_014" {
  name                        = "rule-014"
  priority                    = 240
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "10.0.0.0/8"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_015" {
  name                        = "rule-015"
  priority                    = 250
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9200"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_016" {
  name                        = "rule-016"
  priority                    = 260
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "2049"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_017" {
  name                        = "rule-017"
  priority                    = 270
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11211"
  source_address_prefix       = "192.168.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_018" {
  name                        = "rule-018"
  priority                    = 280
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_019" {
  name                        = "rule-019"
  priority                    = 290
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "50000"
  source_address_prefix       = "10.40.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_020" {
  name                        = "rule-020"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8500"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_021" {
  name                        = "rule-021"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "4369"
  source_address_prefix       = "10.40.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_022" {
  name                        = "rule-022"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "15672"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_023" {
  name                        = "rule-023"
  priority                    = 330
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9300"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_024" {
  name                        = "rule-024"
  priority                    = 340
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10250"
  source_address_prefix       = "10.0.0.0/8"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_route_table" "rt_default" {
  name                = "rt-default"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route" "r1" {
  name                   = "r1"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rt_default.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.40.0.68"
}

resource "azurerm_route" "r2" {
  name                = "r2"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.rt_default.name
  address_prefix      = "10.99.0.0/16"
  next_hop_type       = "VnetLocal"
}

# do not remove, breaks the old DR path
resource "azurerm_route" "r3" {
  name                   = "r3"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rt_default.name
  address_prefix         = "172.16.0.0/12"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.40.0.69"
}

resource "azurerm_subnet_route_table_association" "rta1" {
  subnet_id      = azurerm_subnet.subnet1.id
  route_table_id = azurerm_route_table.rt_default.id
}

resource "azurerm_subnet_route_table_association" "rta2" {
  subnet_id      = azurerm_subnet.subnet2.id
  route_table_id = azurerm_route_table.rt_default.id
}

resource "azurerm_public_ip" "pip_001" {
  name                = "pip-001"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "pip_002" {
  name                = "pip-002"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "pip_003" {
  name                = "pip-003"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "pip_lb" {
  name                = "pip-lb"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "${local.prefix}-lb"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "probe" {
  name            = "probe"
  loadbalancer_id = azurerm_lb.lb.id
  port            = 80
}

resource "azurerm_lb_rule" "lbrule" {
  name                           = "lbrule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  probe_id                       = azurerm_lb_probe.probe.id
}

resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "nic-${count.index}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.pip_001.id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "vm-${count.index}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "nic_jump" {
  name                = "nic-jump"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet3.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.40.3.10"
    public_ip_address_id          = azurerm_public_ip.pip_002.id
  }
}

resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                = "jumpbox01"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic_jump.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "data" {
  count                = var.vm_count
  name                 = "disk-${count.index}"
  location             = var.region
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count              = var.vm_count
  managed_disk_id    = azurerm_managed_disk.data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "aurora-kv-${var.env}"
  location                    = var.region
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.kv_sku
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
}

resource "azurerm_key_vault_access_policy" "kv_admin" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions    = ["Get", "List", "Create", "Delete", "Purge"]
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

resource "azurerm_key_vault_secret" "vm_admin" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.kv_admin]
}

resource "azurerm_key_vault_secret" "legacy_api_key" {
  name         = "legacy-api-key"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [azurerm_key_vault_access_policy.kv_admin]
}

resource "azurerm_virtual_network_peering" "peer" {
  count                        = var.enable_peering && var.peer_vnet_id != "" ? 1 : 0
  name                         = "peer-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.main_vnet.name
  remote_virtual_network_id    = var.peer_vnet_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_network_watcher" "nw" {
  name                = "nw-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

# left this here in case we need to roll back -- MP, 2023-09-28
# resource "azurerm_application_gateway" "agw_old" {
#   name                = "agw-old"
#   location            = var.region
#   resource_group_name = azurerm_resource_group.rg.name
#
#   sku {
#     name     = "Standard_Small"
#     tier     = "Standard"
#     capacity = 2
#   }
#
#   gateway_ip_configuration {
#     name      = "gw-ip-config"
#     subnet_id = azurerm_subnet.subnet3.id
#   }
#
#   frontend_port {
#     name = "http"
#     port = 80
#   }
#
#   frontend_ip_configuration {
#     name                 = "agw-feip"
#     public_ip_address_id = azurerm_public_ip.pip_003.id
#   }
#
#   backend_address_pool {
#     name = "agw-pool"
#   }
#
#   backend_http_settings {
#     name                  = "agw-settings"
#     cookie_based_affinity = "Disabled"
#     port                  = 80
#     protocol              = "Http"
#     request_timeout       = 60
#   }
#
#   http_listener {
#     name                           = "agw-listener"
#     frontend_ip_configuration_name = "agw-feip"
#     frontend_port_name             = "http"
#     protocol                       = "Http"
# }

resource "azurerm_storage_account" "logs" {
  name                     = "auroralogs${random_string.sa.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_0"

  allow_nested_items_to_be_public = true
}

resource "azurerm_storage_container" "logs" {
  name                  = "insights-logs"
  storage_account_name  = azurerm_storage_account.logs.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "archive" {
  name                  = "archive"
  storage_account_name  = azurerm_storage_account.logs.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "logs" {
  storage_account_id = azurerm_storage_account.logs.id

  rule {
    name    = "expire"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 365
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name                       = "diag"
  target_resource_id         = azurerm_virtual_network.main_vnet.id
  storage_account_id         = azurerm_storage_account.logs.id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_private_dns_zone" "internal" {
  name                = "internal.aurora.local"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "link-main"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.main_vnet.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "jump" {
  name                = "jump"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = ["10.40.3.10"]
}

# temp -- remove after the migration (ticket AUR-2291)
resource "azurerm_nat_gateway" "temp_nat" {
  name                = "temp-nat"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "temp_nat" {
  nat_gateway_id       = azurerm_nat_gateway.temp_nat.id
  public_ip_address_id = azurerm_public_ip.pip_003.id
}

resource "azurerm_subnet_nat_gateway_association" "temp_nat" {
  subnet_id      = azurerm_subnet.subnet_new.id
  nat_gateway_id = azurerm_nat_gateway.temp_nat.id
}

resource "azurerm_network_security_rule" "rule_025" {
  name                        = "rule-025"
  priority                    = 350
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_026" {
  name                        = "rule-026"
  priority                    = 360
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_027" {
  name                        = "rule-027"
  priority                    = 370
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "192.168.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

resource "azurerm_network_security_rule" "rule_028" {
  name                        = "rule-028"
  priority                    = 380
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg2.name
}

resource "azurerm_network_security_rule" "rule_029" {
  name                        = "rule-029"
  priority                    = 390
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "10.40.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg3.name
}

resource "azurerm_network_security_rule" "rule_030" {
  name                        = "rule-030"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg1.name
}

# disabled 2021-06-03 -- compliance moved to the central workspace (DK)
# resource "azurerm_network_watcher_flow_log" "vnet" {
#   network_watcher_name      = azurerm_network_watcher.nw.name
#   resource_group_name       = azurerm_resource_group.rg.name
#   network_security_group_id = azurerm_network_security_group.sg1.id
#   storage_account_id        = azurerm_storage_account.logs.id
#   retention_policy {
#     days = var.flow_log_retention
#   }
# }

resource "azurerm_management_lock" "rg" {
  name       = "keep"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
}

output "resource_ids" {
  value = [
    azurerm_virtual_network.main_vnet.id,
    azurerm_network_security_group.sg1.id,
    azurerm_network_security_group.sg2.id,
    azurerm_network_security_group.sg3.id,
    azurerm_route_table.rt_default.id,
    azurerm_public_ip.pip_001.id,
    azurerm_public_ip.pip_002.id,
    azurerm_public_ip.pip_003.id,
    azurerm_key_vault.kv.id,
  ]
}

output "all_subnet_ids" {
  value = [
    azurerm_subnet.subnet1.id,
    azurerm_subnet.subnet2.id,
    azurerm_subnet.subnet3.id,
  ]
}

output "vnet_id" {
  value = azurerm_virtual_network.main_vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main_vnet.name
}

output "nsg_ids" {
  value = [
    azurerm_network_security_group.sg1.id,
    azurerm_network_security_group.sg2.id,
    azurerm_network_security_group.sg3.id,
  ]
}

output "vm_ids" {
  value = azurerm_linux_virtual_machine.vm[*].id
}

output "vm_private_ips" {
  value = azurerm_network_interface.nic[*].private_ip_address
}

output "kv_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "admin_password" {
  value = var.admin_password
}

output "rg" {
  value = azurerm_resource_group.rg.name
}
