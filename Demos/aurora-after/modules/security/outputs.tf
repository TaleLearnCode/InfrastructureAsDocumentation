# module: app-tier-secrets / outputs

output "app_tier_vault_uri" {
  description = "URI of the application-tier Key Vault. Intended for consumption by application configuration. Secret values are never exposed as Terraform outputs; the application reads them at runtime with its managed identity."
  value       = azurerm_key_vault.app_tier_secrets.vault_uri
}

output "app_tier_vault_id" {
  description = "Resource ID of the application-tier Key Vault. Intended for consumers attaching diagnostic settings or private endpoints. Not a grant of access: access is governed by the policies in this module."
  value       = azurerm_key_vault.app_tier_secrets.id
}

output "enforced_minimum_tls_version" {
  description = "The TLS floor this boundary enforces, surfaced so downstream modules can assert the same posture rather than assume it. Reflects Security Policy SP-2023-04."
  value       = var.minimum_tls_version
}
