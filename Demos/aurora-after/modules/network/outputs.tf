# module: private-app-network / outputs
#
# These outputs are the module's public contract. They are named after
# architectural roles, not internal resource identifiers, and each one states
# who is meant to consume it and what invariant it carries. Adding a subnet to
# this module cannot break a consumer, because no consumer depends on ordering.

output "app_tier_subnet_id" {
  description = "ID of the application-tier subnet. Intended for consumption by the compute module. This subnet enforces no public IP assignment via NSG. Do not use for external-facing workloads."
  value       = azurerm_subnet.app_tier.id
}

output "data_tier_subnet_id" {
  description = "ID of the data-tier subnet. Intended for consumption by the data platform module. Isolated from public ingress; reachable only from the application tier on 1433."
  value       = azurerm_subnet.data_tier.id
}

output "management_subnet_id" {
  description = "ID of the operations/management plane subnet. Intended for bastion and administrative tooling. Inbound restricted to corporate source ranges."
  value       = azurerm_subnet.management.id
}

output "private_app_network_id" {
  description = "ID of the private application VNet. Intended for consumers configuring peering or private DNS zone links. Not a handle for creating resources inside this network -- use the subnet outputs for that."
  value       = azurerm_virtual_network.private_app_network.id
}

output "network_address_space" {
  description = "CIDR blocks assigned to this VNet. Intended for consumers writing firewall rules or route entries that must reference this tier. Treat as read-only; IPAM owns allocation."
  value       = azurerm_virtual_network.private_app_network.address_space
}

output "resource_group_name" {
  description = "Resource group holding this network boundary. Intended for consumers that must place peered or linked resources in the same group. Does not imply ownership of anything else inside it."
  value       = azurerm_resource_group.private_app_network.name
}

output "app_tier_network_security_group_id" {
  description = "NSG guarding the application-tier subnet. Intended for consumption by the observability module, which captures flow logs for this boundary. Not an invitation to add rules from outside this module: rules live with the boundary they protect."
  value       = azurerm_network_security_group.app_tier_allow_https.id
}
