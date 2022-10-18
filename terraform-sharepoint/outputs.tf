output "resource_group_name" {
  value = module.sharepoint.resource_group_name
}

output "resource_group_id" {
  value = module.sharepoint.resource_group_id
}

output "vm_dc_dns" {
  value = module.sharepoint.vm_dc_dns
}

output "vm_sql_dns" {
  value = module.sharepoint.vm_sql_dns
}

output "vm_sp_dns" {
  value = module.sharepoint.vm_sp_dns
}

output "vm_fe_dns" {
  value = module.sharepoint.vm_fe_dns
}

output "domain_admin_account" {
  value = module.sharepoint.domain_admin_account
}

output "domain_admin_account_format_bastion" {
  value = module.sharepoint.domain_admin_account_format_bastion
}

output "local_admin_username" {
  value = module.sharepoint.local_admin_username
}

output "admin_password" {
  value     = module.sharepoint.admin_password
  sensitive = true
}

output "service_accounts_password" {
  value     = module.sharepoint.service_accounts_password
  sensitive = true
}
