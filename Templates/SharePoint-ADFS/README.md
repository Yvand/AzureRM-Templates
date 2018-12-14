# Azure template for SharePoint 2013, 2016 and 2019

## Description

This template deploys SharePoint 2013, 2016 and 2019 with following configuration:

* ADFS is installed on the DC and fully configured in SharePoint.
* A certificate authority (ADCS) is provisioned on the DC and is used for all certificates issued to ADFS and SharePoint.
* 1 web application is created with 2 zones: Default zone uses Windows and Intranet zone uses ADFS.
* A couple of site collections are created, including [host-named site collections](https://docs.microsoft.com/en-us/SharePoint/administration/host-named-site-collection-architecture-and-deployment) that are configured for both zones. MySites are also configured as host-named site collections.
* User Profiles and Add-ins service applications are provisioned
* 2 extra DNS zones are created to support SharePoint apps, and app domains are set in both zones of the web application.
* Latest version of claims provider [LDAPCP](https://ldapcp.com/) is installed and configured.
* A font-end can be optionally added to the farm.

Each VM has its own public IP address, and are protected by NSGs (Network Security Group) attached to each subnet. RDP ports are allowed from Internet.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fdev%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

> **Notes:**  
> I strongly recommend to update SharePoint to a recent build just after the provisioning is complete.  
> With the default sizes of virtual machines, provisioning of the template takes about 1h15 to complete.  
> The password complexity check in the form is not accurate and may validate a password that will be rejected by Azure when it provisions the VMs. Make sure to **use at least 2 special characters for the passwords**.
