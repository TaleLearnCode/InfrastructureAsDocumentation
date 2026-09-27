# module: network-flow-logs / outputs

output "flow_log_storage_account_id" {
  description = "Resource ID of the flow log storage account. Intended for consumption by the SIEM ingestion pipeline and by audit tooling. This account holds flow logs and nothing else; do not use it as general-purpose storage."
  value       = azurerm_storage_account.network_flow_logs.id
}

output "flow_log_retention_days" {
  description = "Retention window currently enforced, surfaced so compliance reporting can read the real value from state rather than from a wiki page."
  value       = var.retention_days
}
