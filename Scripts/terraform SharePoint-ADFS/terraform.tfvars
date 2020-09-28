location = "West Europe"
resourceGroupName = "ydterraform4"
dnsLabelPrefix = "ydterraform4"
countOfFrontEndToAdd = 2
sharePointVersion = 2013
vmSP = {
    vmName             = "SP"
    vmSize             = "Standard_E2ds_v4"
    vmImagePublisher   = "MicrosoftSharePoint"
    vmImageOffer       = "MicrosoftSharePointServer"
    vmImageSKU         = "sp2013"
    storageAccountType = "Standard_LRS"
}
_artifactsLocation = "https://github.com/Yvand/AzureRM-Templates/raw/dev/Templates/SharePoint-ADFS/"
