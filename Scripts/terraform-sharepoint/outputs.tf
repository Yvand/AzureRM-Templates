output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "vm_dc_dns" {
  value  = azurerm_public_ip.pip_dc.fqdn
}

output "vm_sql_dns" {
  value  = azurerm_public_ip.pip_sql.fqdn
}

output "vm_sp_dns" {
  value  = azurerm_public_ip.pip_sp.fqdn
}

output "vm_fe_dns" {
  value = azurerm_public_ip.pip_fe[*].fqdn
}

output "domain_admin_account" {
  value = "${split(".", var.domainFQDN)[0]}\\${var.adminUserName}"
}

output "domain_admin_account_format_bastion" {
  value = "${var.adminUserName}@${var.domainFQDN}"
}

output "local_admin_username" {
  value  = azurerm_windows_virtual_machine.vm_sp.admin_username
}