variable "location" {
  default     = "West Europe"
  description = "Location where resources will be provisioned"
}

variable "resource_group_name" {
  description = "Name of the ARM resource group to create"
}

variable "sharepoint_version" {
  default     = "Subscription-22H2"
  description = "Version of SharePoint farm to create."
  validation {
    condition = contains([
      "Subscription-22H2",
      "Subscription-RTM",
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

variable "domain_fqdn" {
  default     = "contoso.local"
  description = "FQDN of the AD forest to create"
}

variable "time_zone" {
  default     = "Romance Standard Time"
  description = "Time zone of the virtual machines."
  validation {
    condition = contains([
      "Dateline Standard Time",
      "UTC-11",
      "Aleutian Standard Time",
      "Hawaiian Standard Time",
      "Marquesas Standard Time",
      "Alaskan Standard Time",
      "UTC-09",
      "Pacific Standard Time (Mexico)",
      "UTC-08",
      "Pacific Standard Time",
      "US Mountain Standard Time",
      "Mountain Standard Time (Mexico)",
      "Mountain Standard Time",
      "Central America Standard Time",
      "Central Standard Time",
      "Easter Island Standard Time",
      "Central Standard Time (Mexico)",
      "Canada Central Standard Time",
      "SA Pacific Standard Time",
      "Eastern Standard Time (Mexico)",
      "Eastern Standard Time",
      "Haiti Standard Time",
      "Cuba Standard Time",
      "US Eastern Standard Time",
      "Turks And Caicos Standard Time",
      "Paraguay Standard Time",
      "Atlantic Standard Time",
      "Venezuela Standard Time",
      "Central Brazilian Standard Time",
      "SA Western Standard Time",
      "Pacific SA Standard Time",
      "Newfoundland Standard Time",
      "Tocantins Standard Time",
      "E. South America Standard Time",
      "SA Eastern Standard Time",
      "Argentina Standard Time",
      "Greenland Standard Time",
      "Montevideo Standard Time",
      "Magallanes Standard Time",
      "Saint Pierre Standard Time",
      "Bahia Standard Time",
      "UTC-02",
      "Mid-Atlantic Standard Time",
      "Azores Standard Time",
      "Cape Verde Standard Time",
      "UTC",
      "GMT Standard Time",
      "Greenwich Standard Time",
      "Sao Tome Standard Time",
      "Morocco Standard Time",
      "W. Europe Standard Time",
      "Central Europe Standard Time",
      "Romance Standard Time",
      "Central European Standard Time",
      "W. Central Africa Standard Time",
      "Jordan Standard Time",
      "GTB Standard Time",
      "Middle East Standard Time",
      "Egypt Standard Time",
      "E. Europe Standard Time",
      "Syria Standard Time",
      "West Bank Standard Time",
      "South Africa Standard Time",
      "FLE Standard Time",
      "Israel Standard Time",
      "Kaliningrad Standard Time",
      "Sudan Standard Time",
      "Libya Standard Time",
      "Namibia Standard Time",
      "Arabic Standard Time",
      "Turkey Standard Time",
      "Arab Standard Time",
      "Belarus Standard Time",
      "Russian Standard Time",
      "E. Africa Standard Time",
      "Iran Standard Time",
      "Arabian Standard Time",
      "Astrakhan Standard Time",
      "Azerbaijan Standard Time",
      "Russia Time Zone 3",
      "Mauritius Standard Time",
      "Saratov Standard Time",
      "Georgian Standard Time",
      "Volgograd Standard Time",
      "Caucasus Standard Time",
      "Afghanistan Standard Time",
      "West Asia Standard Time",
      "Ekaterinburg Standard Time",
      "Pakistan Standard Time",
      "Qyzylorda Standard Time",
      "India Standard Time",
      "Sri Lanka Standard Time",
      "Nepal Standard Time",
      "Central Asia Standard Time",
      "Bangladesh Standard Time",
      "Omsk Standard Time",
      "Myanmar Standard Time",
      "SE Asia Standard Time",
      "Altai Standard Time",
      "W. Mongolia Standard Time",
      "North Asia Standard Time",
      "N. Central Asia Standard Time",
      "Tomsk Standard Time",
      "China Standard Time",
      "North Asia East Standard Time",
      "Singapore Standard Time",
      "W. Australia Standard Time",
      "Taipei Standard Time",
      "Ulaanbaatar Standard Time",
      "Aus Central W. Standard Time",
      "Transbaikal Standard Time",
      "Tokyo Standard Time",
      "North Korea Standard Time",
      "Korea Standard Time",
      "Yakutsk Standard Time",
      "Cen. Australia Standard Time",
      "AUS Central Standard Time",
      "E. Australia Standard Time",
      "AUS Eastern Standard Time",
      "West Pacific Standard Time",
      "Tasmania Standard Time",
      "Vladivostok Standard Time",
      "Lord Howe Standard Time",
      "Bougainville Standard Time",
      "Russia Time Zone 10",
      "Magadan Standard Time",
      "Norfolk Standard Time",
      "Sakhalin Standard Time",
      "Central Pacific Standard Time",
      "Russia Time Zone 11",
      "New Zealand Standard Time",
      "UTC+12",
      "Fiji Standard Time",
      "Kamchatka Standard Time",
      "Chatham Islands Standard Time",
      "UTC+13",
      "Tonga Standard Time",
      "Samoa Standard Time",
      "Line Islands Standard Time"
    ], var.time_zone)
    error_message = "Invalid time zone value."
  }
}

variable "auto_shutdown_time" {
  default     = "1900"
  type        = string
  description = "The time at which VMs will be automatically shutdown (24h HHmm format). Set value to '9999' to NOT configure the auto shutdown."
  validation {
    condition     = length(var.auto_shutdown_time) == 4
    error_message = "The auto_shutdown_time value must contain 4 characters."
  }
}

variable "number_additional_frontend" {
  default     = 0
  description = "Number of MinRole Front-end to add to the farm. The MinRole type can be changed later as needed."
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

variable "_artifactsLocation" {
  default = "https://github.com/Azure/azure-quickstart-templates/raw/master/application-workloads/sharepoint/sharepoint-adfs/"
}

variable "_artifactsLocationSasToken" {
  default = ""
}
