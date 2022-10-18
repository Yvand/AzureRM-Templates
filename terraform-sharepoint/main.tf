module "sharepoint" {
  source                                = "Yvand/sharepoint/azurerm"
  version                               = ">=2.1.0"
  location                              = "France Central"
  resource_group_name                   = var.resource_group_name
  sharepoint_version                    = "Subscription-22H2"
  admin_username                        = "yvand"
  admin_password                        = var.admin_password
  service_accounts_password             = var.service_accounts_password
  domain_fqdn                           = "contoso.local"
  number_additional_frontend            = 0
  enable_hybrid_benefit_server_licenses = true
  add_public_ip_to_each_vm              = true
  rdp_traffic_allowed                   = var.rdp_traffic_allowed
  enable_azure_bastion                  = false
  _artifactsLocation                    = var._artifactsLocation
}
