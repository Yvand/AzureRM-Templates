# Azure template for SharePoint 2019 / 2016 / 2013

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FDTL-SharePoint-FullConfig%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FDTL-SharePoint-FullConfig%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FDTL-SharePoint-FullConfig%2Fazuredeploy.json)

> **Note:** A public version of this template is available at <https://azure.microsoft.com/en-us/resources/templates/sharepoint-adfs/> and <https://github.com/Azure/azure-devtestlab/tree/master/Environments/SharePoint-SingleFarm-FullConfig/>

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

You can connect to virtual machines using:

* [Azure Bastion](https://azure.microsoft.com/en-us/services/azure-bastion/) if you set parameter 'addAzureBastion' to true.
* RDP protocol if you set parameter 'addPublicIPToVMs' to true AND configured parameter 'RDPTrafficAllowed' accordingly.

About network security:

* All subnets are protected by a [Network Security Group](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview).
* Parameter 'RDPTrafficAllowed' may add an incoming rule to the Network Security Groups to allow RDP traffic, depending on how you set it.
* If parameter 'addPublicIPToVMs' is set to true, each machine gets a public IP, a DNS name, and may be reachable from Internet (depending on the configuration of the Network Security Group it depends on).

Default size of virtual machines use [B-series burstable](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable), ideal for such template and much cheaper than other comparable series.  
Below is the default size and storage type per virtual machine role. Prices shown are in US dollar, per month, as of 2021-09-10, in region West Europe, without enabling the '[Azure Hybrid Benefit](https://azure.microsoft.com/en-us/pricing/hybrid-benefit/)' licensing benefit, assuming they run 24*7:

* DC: Size [Standard_B2s](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 4 GiB RAM) ($40.88) and OS disk is a 128 GiB standard HDD ($5.89).
* SQL Server: Size [Standard_B2ms](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 8 GiB RAM) ($75.92) and OS disk is a 128 GiB standard HDD ($5.89).
* SharePoint: Size [Standard_B4ms](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable) (4 vCPU / 16 GiB RAM) ($151.84) and OS disk is a 128 GiB [standard SSD](https://azure.microsoft.com/en-us/blog/preview-standard-ssd-disks-for-azure-virtual-machine-workloads/) ($9.60).

You can visit <https://azure.com/e/cec4eb6f853d43c6bcfaf56be0363ee4> to view the up-to-date cost of the template when provisioned with the default resources, in the region/currency of your choice.

Additional notes:

* I strongly recommend to update SharePoint to a recent build after the deployment completed.  
* With the default settings, the deployment takes about 1h to complete.  
* Once it is completed, the template will return valuable information in the 'Outputs' of the deployment.  
* For various (very good) reasons, the template sets the local (not domain) administrator name with a string that is unique to your subscription (e.g. 'local-q1w2e3r4t5'). You can find the name of the local admin in the 'Outputs' of the deployment once it is completed.  
