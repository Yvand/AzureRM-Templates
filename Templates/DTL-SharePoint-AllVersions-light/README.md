# Azure template for SharePoint 2019 / 2016 / 2013, optimized for DevTest Labs

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS-DevTestLabs%2Fazuredeploy.json)

> **Note:** A public version of this template is available at <https://github.com/Azure/azure-devtestlab/tree/master/Environments/SharePoint-AllVersions>

This template deploys SharePoint 2019, 2016 and 2013. Each SharePoint version is independent and may or may not be deployed, depending on your needs.  
A DC is provisioned and configured with ADFS and ADCS (both are optional), and a unique SQL Server is provisioned for all SharePoint farms.  
Each SharePoint farm has a lightweight configuration to provision quickly: 1 web application with 1 site collection, using Windows NTLM on Default zone, and optionally ADFS on Intranet zone.

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
