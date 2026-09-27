# Aurora root composition / outputs
#
# The root exposes the same kind of contract its modules do: named, described,
# role-oriented. There is no resource_ids dump, and there is no output that
# exists only because a value happened to be convenient to reach.

output "app_tier_subnet_id" {
  description = "Application-tier subnet. Stable contract for any module that places workloads in the application tier."
  value       = module.private_app_network.app_tier_subnet_id
}

output "private_app_network_id" {
  description = "Private application VNet. For consumers configuring peering or private DNS zone links."
  value       = module.private_app_network.private_app_network_id
}

output "app_tier_vault_uri" {
  description = "Key Vault URI for the application tier. Configuration reads secrets at runtime with a managed identity; no secret value is exported here."
  value       = module.app_tier_secrets.app_tier_vault_uri
}
