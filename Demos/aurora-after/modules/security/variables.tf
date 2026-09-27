# module: app-tier-secrets / variables

variable "deployment_environment" {
  type        = string
  description = "Target environment. Governs naming, tagging, and the purge-protection posture. No default: this is a conscious decision per deployment."

  validation {
    condition     = contains(["prod", "staging", "dev"], var.deployment_environment)
    error_message = "Must be prod, staging, or dev."
  }
}

variable "region" {
  type        = string
  description = "Azure region. Must match the tier this vault serves; cross-region vault access adds latency to every secret read."

  validation {
    condition     = contains(["eastus", "westus2", "northeurope"], var.region)
    error_message = "Valid regions are eastus, westus2, northeurope."
  }
}

variable "owning_team" {
  type        = string
  description = "Team accountable for the secrets in this vault, and the team a reviewer escalates to when an access policy changes."
}

variable "minimum_tls_version" {
  type        = string
  description = "Minimum TLS version accepted by this boundary. Default enforces Security Policy SP-2023-04. Lowering it below TLS 1.2 is a policy violation, not a compatibility setting."
  default     = "TLS1_2"

  validation {
    condition     = contains(["TLS1_2", "TLS1_3"], var.minimum_tls_version)
    error_message = "TLS 1.0 and 1.1 are not permitted. Security Policy SP-2023-04 took effect 2023-04-01."
  }
}

variable "authorized_principal_ids" {
  type        = list(string)
  description = "Managed identity principal IDs permitted to read secrets. Supplied by the compute module's app_tier_principal_ids output. Human users are not granted access here; they use PIM."
  default     = []
}

variable "network_access_subnet_ids" {
  type        = list(string)
  description = "Subnets permitted to reach the vault. Defaults to empty, which means the vault is unreachable until a caller declares the boundary it serves -- a deliberate decision point."
  default     = []
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged over the governance tags this module always applies."
  default     = {}
}
