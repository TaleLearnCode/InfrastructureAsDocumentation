# module: network-flow-logs / variables

variable "deployment_environment" {
  type        = string
  description = "Target environment. Governs naming, tagging, and the retention period applied to captured flow logs. No default: this is a conscious decision per deployment."

  validation {
    condition     = contains(["prod", "staging", "dev"], var.deployment_environment)
    error_message = "Must be prod, staging, or dev."
  }
}

variable "region" {
  type        = string
  description = "Azure region. Must match the network being observed; Network Watcher is a regional service and cannot capture flow logs across regions."

  validation {
    condition     = contains(["eastus", "westus2", "northeurope"], var.region)
    error_message = "Valid regions are eastus, westus2, northeurope."
  }
}

variable "owning_team" {
  type        = string
  description = "Team accountable for flow log retention and for answering audit requests about this data."
}

variable "observed_network_security_group_id" {
  type        = string
  description = "NSG whose traffic is captured. Supplied by the network module. This module exists to observe a network boundary; it never creates one."
}

variable "minimum_tls_version" {
  type        = string
  description = "Minimum TLS version accepted by the flow log storage account. Default enforces Security Policy SP-2023-04. TLS 1.0 was the provider default when Aurora first wrote this; it is not a default anyone chose."
  default     = "TLS1_2"

  validation {
    condition     = contains(["TLS1_2", "TLS1_3"], var.minimum_tls_version)
    error_message = "TLS 1.0 and 1.1 are not permitted. Security Policy SP-2023-04 took effect 2023-04-01."
  }
}

variable "retention_days" {
  type        = number
  description = "Days of flow log retention. Defaults to 90 to match the security incident review window; the compliance obligation, not a storage cost target, sets this number."
  default     = 90

  validation {
    condition     = var.retention_days >= 30
    error_message = "Retention below 30 days breaks the incident review window agreed with Security."
  }
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged over the governance tags this module always applies."
  default     = {}
}
