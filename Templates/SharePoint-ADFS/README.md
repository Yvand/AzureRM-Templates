# Azure template for SharePoint 2013, 2016 and 2019

This template deploys SharePoint 2013, 2016 and 2019 with following configuration:

* ADFS is installed on the DC and fully configured in SharePoint.
* A certificate authority (ADCS) is provisioned on the DC and is used for all certificates issued to ADFS and SharePoint.
* 1 web application is created with 2 zones: Default zone uses Windows and Intranet zone uses ADFS.
* A couple of site collections are created, including [host-named site collections](https://docs.microsoft.com/en-us/SharePoint/administration/host-named-site-collection-architecture-and-deployment) that are configured for both zones. MySites are also configured as host-named site collections.
* User Profiles and Add-ins service applications are provisioned
* 2 extra DNS zones are created to support SharePoint apps, and app domains are set in both zones of the web application.
* Latest version of claims provider [LDAPCP](https://ldapcp.com/) is installed and configured.
* A font-end can be optionally added to the farm.

Each VM has its own public IP address, and they are protected by NSGs (Network Security Group) attached to each subnet. RDP ports are allowed from Internet.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

By default, virtual machines running SharePoint and SQL use SSD drives and have enough CPU and memory to be used comfortably for development and tests, as long as Search service is not started:

* Virtual machine "DC":
  * vmDCSize: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup)
  * vmDCStorageAccountType: Standard_LRS
* Virtual machine "SQL":
  * vmSQLSize: [Standard_DS2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series)
  * vmSQLStorageAccountType: Premium_LRS
* Virtual machines "SP" and "FE":
  * vmSPSize: [Standard_DS3_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dsv2-series)
  * vmSPStorageAccountType: Premium_LRS

I recommended the following options if you wish to provision a cheap environment:

* Virtual machine "DC":
  * vmDCSize: [Standard_F4](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-compute#fsv2-series-sup1sup)
  * vmDCStorageAccountType: Standard_LRS
* Virtual machine "SQL":
  * vmSQLSize: [Standard_D2_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general#dv2-series)
  * vmSQLStorageAccountType: Standard_LRS
* Virtual machines "SP" and "FE":
  * vmSPSize: [Standard_D11_v2](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-memory#dv2-series-11-15)
  * vmSPStorageAccountType: Standard_LRS

> **Notes:**  
> I strongly recommend to update SharePoint to a recent build just after the provisioning is complete.  
> With the default sizes of virtual machines, provisioning of the template takes about 1h15 to complete.  
> The password complexity check in the form is not accurate and may validate a password that will be rejected by Azure when it provisions the VMs. Make sure to **use at least 2 special characters for the passwords**.
