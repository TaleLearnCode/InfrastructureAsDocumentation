# module: app-tier-compute / variables

variable "deployment_environment" {
  type        = string
  description = "Target environment. Governs naming, tagging, and instance sizing policy. No default: this is a conscious decision per deployment."

  validation {
    condition     = contains(["prod", "staging", "dev"], var.deployment_environment)
    error_message = "Must be prod, staging, or dev."
  }
}

variable "region" {
  type        = string
  description = "Azure region. Must match the region of the network module that produced app_tier_subnet_id; cross-region NIC attachment is not supported."

  validation {
    condition     = contains(["eastus", "westus2", "northeurope"], var.region)
    error_message = "Valid regions are eastus, westus2, northeurope."
  }
}

variable "owning_team" {
  type        = string
  description = "Team accountable for these instances. Written into the owner tag and used by the on-call routing rules."
}

variable "app_tier_subnet_id" {
  type        = string
  description = "Subnet the application tier runs in. Supplied by the network module's app_tier_subnet_id output. That subnet forbids public IPs; this module relies on that invariant."
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key for the break-glass admin account. No default and no password authentication: Aurora does not ship credentials in Terraform, per Security Policy SP-2023-04."
}

variable "instance_count" {
  type        = number
  description = "Number of application-tier instances. Defaults to 3 to survive a single zone failure with quorum intact; below 3 is a deliberate availability trade-off."
  default     = 3

  validation {
    condition     = var.instance_count >= 2
    error_message = "The application tier is not run as a single instance. Use at least 2; 3 is the supported production shape."
  }
}

variable "instance_size" {
  type        = string
  description = "VM size. Defaults to the size the capacity model was built against; changing it invalidates the published latency budget."
  default     = "Standard_D2s_v3"
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged over the governance tags this module always applies."
  default     = {}
}
