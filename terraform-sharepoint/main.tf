module "sharepoint" {
  source                     = "Yvand/sharepoint/azurerm"
  version                    = ">=2.0.0"
  location                   = "France Central"
  resource_group_name        = "spsterraform1"
  sharepoint_version         = "2013" #"Subscription-22H2"
  admin_username             = "yvand"
  domain_fqdn                = "contoso.local"
  number_additional_frontend = 0
  rdp_traffic_allowed        = "10.20.30.40"
  enable_azure_bastion       = false
}
