module "sharepoint" {
  source                     = "Yvand/sharepoint/azurerm"
  version                    = "1.3.0"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  sharepoint_version         = var.sharepoint_version
  admin_username             = var.admin_username
  admin_password             = var.admin_password
  service_accounts_password  = var.service_accounts_password
  domain_fqdn                = var.domain_fqdn
  time_zone                  = var.time_zone
  auto_shutdown_time         = var.auto_shutdown_time
  number_additional_frontend = var.number_additional_frontend
  rdp_traffic_allowed        = var.rdp_traffic_allowed
  enable_azure_bastion       = var.enable_azure_bastion
  _artifactsLocation         = var._artifactsLocation
  _artifactsLocationSasToken = var._artifactsLocationSasToken
}
