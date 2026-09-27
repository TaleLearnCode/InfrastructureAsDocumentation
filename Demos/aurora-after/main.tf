# Aurora -- private application tier, composed from four boundaries.
#
# The blob module this replaces did all of this in one 1,100-line file. The
# resources are the same. What changed is that each module now maps to exactly
# one architectural boundary, and every dependency between them is an explicit,
# named, described output rather than a reference inside a shared file.

terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Network boundary: VNets, subnets, NSGs. Nothing else.
module "private_app_network" {
  source = "./modules/network"

  deployment_environment = var.deployment_environment
  region                 = var.region
  owning_team            = "platform-engineering"
}

# Compute boundary: consumes a subnet, creates instances.
module "app_tier_compute" {
  source = "./modules/compute"

  deployment_environment = var.deployment_environment
  region                 = var.region
  owning_team            = "application-platform"

  app_tier_subnet_id   = module.private_app_network.app_tier_subnet_id
  admin_ssh_public_key = var.admin_ssh_public_key
}

# Security boundary: consumes identities and a subnet, creates the vault.
module "app_tier_secrets" {
  source = "./modules/security"

  deployment_environment = var.deployment_environment
  region                 = var.region
  owning_team            = "security-engineering"

  authorized_principal_ids  = module.app_tier_compute.app_tier_principal_ids
  network_access_subnet_ids = [module.private_app_network.app_tier_subnet_id]
}

# Observability boundary: the mystery storage account, given a home and a name.
module "network_flow_logs" {
  source = "./modules/observability"

  deployment_environment = var.deployment_environment
  region                 = var.region
  owning_team            = "security-engineering"

  observed_network_security_group_id = module.private_app_network.app_tier_network_security_group_id
}
