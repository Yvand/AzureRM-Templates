module "sharepoint" {
  source                                = "Yvand/sharepoint/azurerm"
  version                               = ">=3.2.0"
  location                              = "France Central"
  resource_group_name                   = var.resource_group_name
  sharepoint_version                    = "2019" #"Subscription-Latest"
  admin_username                        = "yvand"
  admin_password                        = var.admin_password
  service_accounts_password             = var.service_accounts_password
  domain_fqdn                           = "contoso.local"
  number_additional_frontend            = 0
  enable_hybrid_benefit_server_licenses = true
  add_public_ip_address                 = "SharePointVMsOnly"
  rdp_traffic_allowed                   = var.rdp_traffic_allowed
  enable_azure_bastion                  = false
}
