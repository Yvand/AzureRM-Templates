# Azure template for SharePoint 2019 / 2016 / 2013, optimized for DevTest Labs

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)

> **Note:** A public version of this template is available at <https://github.com/Azure/azure-devtestlab/tree/master/Environments/SharePoint-AllVersions>

This template deploys SharePoint 2019, 2016 and 2013. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS (optional) and ADCS, and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has 1 web application created with 2 zones: Windows NTLM on Default zone and ADFS on Intranet zone (optional). They have a minimum configuration to provision quickly.

All subnets connected to a virtual machine are protected by a Network Security Group. You can connect to virtual machines using:

* [Azure Bastion](https://azure.microsoft.com/en-us/services/azure-bastion/) if you set parameter addAzureBastion to 'Yes'.
* RDP protocol if you set parameter addPublicIPToVMs to 'Yes'. Each machine will have a public IP, a DNS name, and the TCP port 3389 will be allowed from Internet.

By default, virtual machines use standard storage and are sized with a good balance between cost and performance:

* Virtual machine running the Domain Controller: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup) / Standard_LRS
* Virtual machine running SQL Server: [Standard_D2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dv2-series) / Standard_LRS
* Virtual machine(s) running SharePoint: [Standard_D11_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-memory#dv2-series-11-15) / Standard_LRS

If you wish to get better performance, I recommended the following sizes / storage account types:

* Virtual machine running the Domain Controller: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup) / Standard_LRS
* Virtual machine running SQL Server: [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series) / Premium_LRS
* Virtual machine(s) running SharePoint: [Standard_DS3_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series) / Premium_LRS
