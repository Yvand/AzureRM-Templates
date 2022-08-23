variable "location" {
  default     = "West Europe"
  description = "Location where resources will be provisioned"
}

variable "resourceGroupName" {
  description = "Name of the ARM resource group to create"
}

variable "sharePointVersion" {
  default     = "SE"
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

variable "numberOfAdditionalFrontEnd" {
  default     = 0
  description = "Type how many additional front ends should be added to the SharePoint farm"
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
    vNetPrivatePrefix          = "10.1.0.0/16"
    vNetPrivateSubnetDCPrefix  = "10.1.1.0/24"
    vNetPrivateSubnetSQLPrefix = "10.1.2.0/24"
    vNetPrivateSubnetSPPrefix  = "10.1.3.0/24"
    vmDCPrivateIPAddress       = "10.1.1.4"
  }
}

variable "vmDC" {
  type = map(string)
  default = {
    vmName             = "DC"
    vmSize             = "Standard_B2s"
    vmImagePublisher   = "MicrosoftWindowsServer"
    vmImageOffer       = "WindowsServer"
    vmImageSKU         = "2022-datacenter-azure-edition-smalldisk"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmSQL" {
  type = map(string)
  default = {
    vmName             = "SQL"
    vmSize             = "Standard_B2ms"
    vmImagePublisher   = "MicrosoftSQLServer"
    vmImageOffer       = "sql2019-ws2022"
    vmImageSKU         = "sqldev-gen2"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmSP" {
  type = map(string)
  default = {
    vmName = "SP"
    vmSize = "Standard_B4ms"
    # vmImagePublisher   = "MicrosoftWindowsServer"
    # vmImageOffer       = "WindowsServer"
    # vmImageSKU         = "2022-datacenter-azure-edition"
    storageAccountType = "Standard_LRS"
  }
}

variable "vmSP_image" {
  type = map(any)
  default = {
    "SE"   = "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest"
    "2019" = "MicrosoftSharePoint:MicrosoftSharePointServer:sp2019:latest"
    "2016" = "MicrosoftSharePoint:MicrosoftSharePointServer:sp2016:latest"
    "2013" = "MicrosoftSharePoint:MicrosoftSharePointServer:sp2013:latest"
  }
}

variable "vmFE" {
  type = map(string)
  default = {
    vmName = "FE"
    vmSize = "Standard_B4ms"
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
  default = "https://github.com/Yvand/AzureRM-Templates/raw/master/SharePoint/SharePoint-ADFS/"
}

variable "_artifactsLocationSasToken" {
  default = ""
}
