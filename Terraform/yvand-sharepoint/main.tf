variable "resource_group_name" {}
variable "subscription_id" {}
variable "admin_password" {}
variable "other_accounts_password" {}
variable "rdp_traffic_rule" {}
variable "tags" {}
# variable "_artifactsLocation" {}

module "sharepoint" {
  source                                = "Yvand/sharepoint/azurerm"
  version                               = "~> 7.0"
  location                              = "francecentral"
  subscription_id                       = var.subscription_id
  resource_group_name                   = var.resource_group_name
  sharepoint_version                    = "Subscription-Latest" #"2019"
  outbound_access_method                = "PublicIPAddress"
  rdp_traffic_rule                      = var.rdp_traffic_rule
  enable_azure_bastion                  = true
  admin_username                        = "yvand"
  admin_password                        = var.admin_password
  other_accounts_password               = var.other_accounts_password
  domain_fqdn                           = "contoso.local"
  enable_hybrid_benefit_server_licenses = true
  add_default_tags                      = true
  tags                                  = var.tags
  # _artifactsLocation                    = var._artifactsLocation
}
