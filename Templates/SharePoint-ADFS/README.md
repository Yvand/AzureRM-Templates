# Azure template for SharePoint 2019 / 2016 / 2013

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)

> **Note:** A public version of this template is available at <https://azure.microsoft.com/en-us/resources/templates/sharepoint-adfs/>

This template deploys SharePoint 2019, 2016 or 2013 with the following configuration:

* 1 web application created with 2 zones: Windows NTLM on Default zone and ADFS on Intranet zone.
* ADFS is installed on the DC, and SAML trust is configured in SharePoint.
* A certificate authority (ADCS) is provisioned on the DC and issues all certificates needed for ADFS and SharePoint.
* A couple of site collections are created, including [host-named site collections](https://docs.microsoft.com/en-us/SharePoint/administration/host-named-site-collection-architecture-and-deployment) that are configured for both zones.
* User Profiles Application service is provisioned and personal sites are configured as [host-named site collections](https://docs.microsoft.com/en-us/SharePoint/administration/host-named-site-collection-architecture-and-deployment).
* Add-ins service application is provisioned and an app catalog is created.
* 2 app domains are set (1 for for each zone of the web application) and corresponding DNS zones are created.
* Latest version of claims provider [LDAPCP](https://ldapcp.com/) is installed and configured.
* A 2nd SharePoint server can optionally be added to the farm.

All subnets connected to a virtual machine are protected by a Network Security Group. You can connect to virtual machines using:

* [Azure Bastion](https://azure.microsoft.com/en-us/services/azure-bastion/) if you set parameter addAzureBastion to 'Yes'.
* RDP protocol if you set parameter addPublicIPToVMs to 'Yes'. Each machine will have a public IP, a DNS name, and the TCP port 3389 will be allowed from Internet.

By default, virtual machines use standard storage and have enough CPU and memory to be used comfortably:

* Virtual machine running the Domain Controller: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup) / Standard_LRS
* Virtual machine running SQL Server: [Standard_D2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dv2-series) / Standard_LRS
* Virtual machine(s) running SharePoint: [Standard_D11_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-memory#dv2-series-11-15) / Standard_LRS

If you wish to get better performance, I recommended the following sizes / storage account types:

* Virtual machine running the Domain Controller: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup) / Standard_LRS
* Virtual machine running SQL Server: [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series) / Premium_LRS
* Virtual machine(s) running SharePoint: [Standard_DS3_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series) / Premium_LRS

> **Notes:**  
> I strongly recommend to update SharePoint to a recent build just after the provisioning is complete.  
> With the default setting for virtual machines, provisioning of the template takes about 1h15 to complete.  
> The password complexity check in the form is not accurate and may validate a password that will be rejected by Azure when it provisions the VMs. Make sure to **use at least 2 special characters for the passwords**.

