# Aurora root composition / variables

variable "deployment_environment" {
  type        = string
  description = "Target environment for the whole application tier. No default: every deployment names its environment explicitly."

  validation {
    condition     = contains(["prod", "staging", "dev"], var.deployment_environment)
    error_message = "Must be prod, staging, or dev."
  }
}

variable "region" {
  type        = string
  description = "Azure region for the whole application tier. Constrained by data-residency approval and hub VNet availability."

  validation {
    condition     = contains(["eastus", "westus2", "northeurope"], var.region)
    error_message = "Valid regions are eastus, westus2, northeurope."
  }
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Break-glass SSH public key for the application tier. Sourced from the platform key register; no password authentication exists as an alternative."
}
