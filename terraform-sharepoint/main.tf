module "sharepoint" {
  source                    = "Yvand/sharepoint/azurerm"
  version                   = "1.3.0"
  resource_group_name       = var.resource_group_name
  sharepoint_version        = var.sharepoint_version
  admin_username            = var.admin_username
  admin_password            = var.admin_password
  service_accounts_password = var.service_accounts_password
  rdp_traffic_allowed       = var.rdp_traffic_allowed
  enable_azure_bastion      = var.enable_azure_bastion
}
