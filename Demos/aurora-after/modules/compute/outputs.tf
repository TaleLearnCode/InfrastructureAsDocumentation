# module: app-tier-compute / outputs

output "app_tier_instance_ids" {
  description = "Resource IDs of the application-tier VMs. Intended for consumption by the load balancer and backup modules. Order is not part of the contract; do not index into this list to identify a specific instance."
  value       = azurerm_linux_virtual_machine.app_tier[*].id
}

output "app_tier_principal_ids" {
  description = "System-assigned managed identity principal IDs. Intended for the security module when granting Key Vault access. These are the only identities the application tier authenticates as."
  value       = azurerm_linux_virtual_machine.app_tier[*].identity[0].principal_id
}

output "app_tier_private_ip_addresses" {
  description = "Private IPs of the application-tier NICs. Intended for internal DNS registration and firewall rules. These addresses are dynamic; consumers must tolerate them changing on replacement."
  value       = azurerm_network_interface.app_tier[*].private_ip_address
}
