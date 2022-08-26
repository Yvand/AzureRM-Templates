variable "location" {
  default     = "West Europe"
  description = "Location where resources will be provisioned"
}

variable "resource_group_name" {
  description = "Name of the ARM resource group to create"
}

variable "sharepoint_version" {
  default     = "SE"
  description = "Version of SharePoint farm to create."
  validation {
    condition = contains([
      "SE",
      "2019",
      "2016",
      "2013"
    ], var.sharepoint_version)
    error_message = "Invalid SharePoint farm version."
  }
}

variable "admin_username" {
  default     = "yvand"
  description = "Name of the AD and SharePoint administrator. 'administrator' is not allowed"
}

variable "admin_password" {
  description = "Input must meet password complexity requirements as documented for property 'admin_password' in https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/virtualmachines-create-or-update"
}

variable "service_accounts_password" {
  description = "Input must meet password complexity requirements as documented for property 'admin_password' in https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/virtualmachines-create-or-update"
}

variable "rdp_traffic_allowed" {
  default     = "No"
  description = "Specify if RDP traffic is allowed to connect to the VMs:<br>- If 'No' (default): Firewall denies all incoming RDP traffic from Internet.<br>- If '*' or 'Internet': Firewall accepts all incoming RDP traffic from Internet.<br>- If 'ServiceTagName': Firewall accepts all incoming RDP traffic from the specified 'ServiceTagName'.<br>- If 'xx.xx.xx.xx': Firewall accepts incoming RDP traffic only from the IP 'xx.xx.xx.xx'."
}

variable "enable_azure_bastion" {
  default     = false
  type        = bool
  description = "Specify if Azure Bastion should be provisioned. See https://azure.microsoft.com/en-us/services/azure-bastion for more information."
}