variable "location" {
  default = "West Europe"
}
variable "resourceGroupName" {}
variable "dnsLabelPrefix" {}
variable "adminUserName" {
    default = "yvand"
}
variable "adminPassword" {}
variable "domainFQDN" {
  default = "contoso.local"
}
variable "timeZone" {
  default = "Romance Standard Time"
}
variable "generalSettings" {
  type = "map"
  default = {
    dscScriptsFolder = "dsc"
    adfsSvcUserName = "adfssvc"
    sqlSvcUserName = "sqlsvc"
    spSetupUserName =  "spsetup"
    spFarmUserName = "spfarm"
    spSvcUserName = "spsvc"
    spAppPoolUserName = "spapppool"
    spSuperUserName = "spSuperUser"
    spSuperReaderName = "spSuperReader"
    sqlAlias = "SQLAlias"
  }
}
variable "networkSettings" {
  type = "map"
  default = {
    vNetPrivatePrefix = "10.0.0.0/16"
    vNetPrivateSubnetDCPrefix = "10.0.1.0/24"
    vNetPrivateSubnetSQLPrefix = "10.0.2.0/24"
    vNetPrivateSubnetSPPrefix = "10.0.3.0/24"
    vmDCPrivateIPAddress = "10.0.1.4"
  }
}
variable "vmDC" {
  type = "map"
  default = {
    vmName = "DC"
    vmSize = "Standard_F4"
    vmImagePublisher = "MicrosoftWindowsServer"
    vmImageOffer = "WindowsServer"
    vmImageSKU = "2016-Datacenter"
    storageAccountType = "Standard_LRS"
  }
}
variable "vmSQL" {
  type = "map"
  default = {
    vmName = "SQL"
    vmSize = "Standard_DS2_v2"
    vmImagePublisher = "MicrosoftSQLServer"
    vmImageOffer = "SQL2016SP1-WS2016"
    vmImageSKU = "Standard"
    storageAccountType = "Standard_LRS"
  }
}
variable "vmSP" {
  type = "map"
  default = {
    vmName = "SP"
    vmSize = "Standard_DS3_v2"
    vmImagePublisher = "MicrosoftSharePoint"
    vmImageOffer = "MicrosoftSharePointServer"
    vmImageSKU = "2016"
    storageAccountType = "Standard_LRS"
  }
}
variable "dscConfigureDCVM" {
  type = "map"
  default = {
    fileName = "ConfigureDCVM.zip"
    script = "ConfigureDCVM.ps1"
    function = "ConfigureDCVM"
    forceUpdateTag = "1.0"
  }
}
variable "dscConfigureSQLVM" {
  type = "map"
  default = {
    fileName = "ConfigureSQLVM.zip"
    script = "ConfigureSQLVM.ps1"
    function = "ConfigureSQLVM"
    forceUpdateTag = "1.0"
  }
}
variable "dscConfigureSPVM" {
  type = "map"
  default = {
    fileName = "ConfigureSPVM.zip"
    script = "ConfigureSPVM.ps1"
    function = "ConfigureSPVM"
    forceUpdateTag = "1.0"
  }
}
variable "_artifactsLocation" {
  default = "https://github.com/Yvand/AzureRM-Templates/raw/master/SharePoint/SharePoint-ADFS"
}
variable "_artifactsLocationSasToken" {
  default = ""
}