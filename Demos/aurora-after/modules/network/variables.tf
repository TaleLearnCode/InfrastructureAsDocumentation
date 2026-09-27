# module: private-app-network / variables
#
# Every variable in this file is a communication decision. Descriptions explain
# intent, validation blocks declare the assumptions the module makes about its
# operating environment, and the deliberate absence of a default marks a
# decision the caller must make consciously.

variable "deployment_environment" {
  type        = string
  description = <<-EOT
    Target environment for this network tier. Governs resource naming, tag
    values, and peering topology. No default: the environment is a conscious
    decision at every deployment, not something this module guesses for you.
  EOT

  validation {
    condition     = contains(["prod", "staging", "dev"], var.deployment_environment)
    error_message = "Must be prod, staging, or dev. Aurora does not run other environment names; 'stg' and 'production' are rejected on purpose."
  }
}

variable "region" {
  type        = string
  description = <<-EOT
    Azure region for the private application tier. Constrained to the regions
    where Aurora holds data-residency approval and where the hub VNet exists
    for peering. Deploying elsewhere is a governance decision, not a variable
    change: talk to Platform Engineering first.
  EOT

  validation {
    condition     = contains(["eastus", "westus2", "northeurope"], var.region)
    error_message = "Valid regions are eastus, westus2, northeurope. Other regions have no hub VNet to peer with and no approved data-residency posture."
  }
}

variable "owning_team" {
  type        = string
  description = "Team accountable for this network tier. Written into the owner tag on every resource so that an on-call engineer can find a human at 2 AM."
}

variable "network_address_space" {
  type        = list(string)
  description = "CIDR blocks for the private application VNet. Must be allocated by the IPAM register before use; overlapping ranges break hub peering silently."
  default     = ["10.40.0.0/16"]
}

variable "app_tier_address_prefix" {
  type        = string
  description = "CIDR for the application-tier subnet. /24 sized deliberately: the tier scales horizontally behind the load balancer and has outgrown /27 twice."
  default     = "10.40.1.0/24"
}

variable "data_tier_address_prefix" {
  type        = string
  description = "CIDR for the data-tier subnet. Carries no route to the internet; egress is via the hub firewall only."
  default     = "10.40.2.0/24"
}

variable "management_address_prefix" {
  type        = string
  description = "CIDR for the management/ops plane subnet. Reachable only from the corporate ranges declared in management_source_ranges."
  default     = "10.40.3.0/24"
}

variable "management_source_ranges" {
  type        = list(string)
  description = "Corporate CIDRs permitted to reach the management subnet. Defaults to the VPN concentrator ranges; widening this is a security review, not a config change."
  default     = ["10.10.0.0/16"]
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged over the governance tags this module always applies. Cannot override owner, environment, or managed_by."
  default     = {}
}
