output "resource_group_id" {
  value = azurerm_resource_group.resourceGroup.id
}

output "vm_dc_dns" {
  value  = azurerm_public_ip.PublicIP-DC.fqdn
}

output "vm_sql_dns" {
  value  = azurerm_public_ip.PublicIP-SQL.fqdn
}

output "vm_sp_dns" {
  value  = azurerm_public_ip.PublicIP-SP.fqdn
}

output "vm_fe_dns" {
  value = var.numberOfAdditionalFrontEnd > 0 ? element(azurerm_public_ip.PublicIP-FE, var.numberOfAdditionalFrontEnd).fqdn : "None"
}

output "domain_admin_account" {
  value = "${split(".", var.domainFQDN)[0]}\\${var.adminUserName}"
}

output "domain_admin_account_format_bastion" {
  value = "${var.adminUserName}@${var.domainFQDN}"
}

output "local_admin_username" {
  value  = azurerm_windows_virtual_machine.VM-SP.admin_username
}