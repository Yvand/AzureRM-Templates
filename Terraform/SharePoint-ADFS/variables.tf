variable "location" {
  default     = "West Europe"
  description = "Location where resources will be provisioned"
}

variable "resourceGroupName" {
  description = "Name of the ARM resource group to create"
}

variable "dnsLabelPrefix" {
  description = "Prefix of public DNS names of VMs, e.g. 'dnsLabelPrefix-VMName.region.cloudapp.azure.com'"
}

variable "adminUserName" {
  default     = "yvand"
  description = "Name of the AD and SharePoint administrator. 'administrator' is not allowed"
}

variable "adminPassword" {
  description = "Input must meet password complexity requirements as documented for property 'adminPassword' in https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/virtualmachines-create-or-update"
}

variable "serviceAccountsPassword" {
  description = "Input must meet password complexity requirements as documented for property 'adminPassword' in https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/virtualmachines-create-or-update"
}

variable "domainFQDN" {
  default     = "contoso.local"
  description = "FQDN of the AD forest to create"
}

variable "timeZone" {
  default     = "Romance Standard Time"
  description = "Time zone of the VMs. Type '[TimeZoneInfo]::GetSystemTimeZones().Id' in PowerShell to get the list. Note that 'UTC' works but 'UTC+xx' does NOT work."
}

variable "addFrontEndToFarm" {
  default     = false
  description = "Select whether a SharePoint Front End VM should be provisioned and joined to the farm."
}

variable "generalSettings" {
  type = map(string)
  default = {
    dscScriptsFolder  = "dsc"
    adfsSvcUserName   = "adfssvc"
    sqlSvcUserName    = "sqlsvc"
    spSetupUserName   = "spsetup"
    spFarmUserName    = "spfarm"
    spSvcUserName     = "spsvc"
    spAppPoolUserName = "spapppool"
    spSuperUserName   = "spSuperUser"
    spSuperReaderName = "spSuperReader"
    sqlAlias          = "SQLAlias"
  }
}

variable "networkSettings" {
  type = map(string)
  default = {
    vNetPrivatePrefix          = "10.0.0.0/16"
    vNetPrivateSubnetDCPrefix  = "10.0.1.0/24"
    vNetPrivateSubnetSQLPrefix = "10.0.2.0/24"
    vNetPrivateSubnetSPPrefix  = "10.0.3.0/24"
    vmDCPrivateIPAddress       = "10.0.1.4"
  }
}

variable "vmDC" {
  type = map(string)
  default = {
    vmName             = "DC"
    vmSize             = "Standard_F4"
    vmImagePublisher   = "MicrosoftWindowsServer"
    vmImageOffer       = "WindowsServer"
    vmImageSKU         = "2016-Datacenter"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmSQL" {
  type = map(string)
  default = {
    vmName             = "SQL"
    vmSize             = "Standard_DS2_v2"
    vmImagePublisher   = "MicrosoftSQLServer"
    vmImageOffer       = "SQL2016SP1-WS2016"
    vmImageSKU         = "Standard"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmSP" {
  type = map(string)
  default = {
    vmName             = "SP"
    vmSize             = "Standard_DS3_v2"
    vmImagePublisher   = "MicrosoftSharePoint"
    vmImageOffer       = "MicrosoftSharePointServer"
    vmImageSKU         = "2016"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmFE" {
  type = map(string)
  default = {
    vmName = "FE"
    vmSize = "Standard_DS3_v2"
  }
}

variable "dscConfigureDCVM" {
  type = map(string)
  default = {
    fileName       = "ConfigureDCVM.zip"
    script         = "ConfigureDCVM.ps1"
    function       = "ConfigureDCVM"
    forceUpdateTag = "1.0"
  }
}

variable "dscConfigureSQLVM" {
  type = map(string)
  default = {
    fileName       = "ConfigureSQLVM.zip"
    script         = "ConfigureSQLVM.ps1"
    function       = "ConfigureSQLVM"
    forceUpdateTag = "1.0"
  }
}

variable "dscConfigureSPVM" {
  type = map(string)
  default = {
    fileName       = "ConfigureSPVM.zip"
    script         = "ConfigureSPVM.ps1"
    function       = "ConfigureSPVM"
    forceUpdateTag = "1.0"
  }
}

variable "dscConfigureFEVM" {
  type = map(string)
  default = {
    fileName       = "ConfigureFEVM.zip"
    script         = "ConfigureFEVM.ps1"
    function       = "ConfigureFEVM"
    forceUpdateTag = "1.0"
  }
}

variable "_artifactsLocation" {
  default = "https://github.com/Yvand/AzureRM-Templates/raw/master/SharePoint/SharePoint-ADFS"
}

variable "_artifactsLocationSasToken" {
  default = ""
}

