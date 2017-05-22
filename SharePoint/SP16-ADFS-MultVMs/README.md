# AzureRM template for SharePoint 2016 with ADFS and Two SP VM 

## This template is based on Yvand SharePoint 2016 

[Yvand Github repos with initial is available here](https://github.com/Yvand/AzureRM-Templates/tree/master/SharePoint/SP16-ADFS)

## Description
This template deploys 4 new Azure VMs, each with its own public IP address and subnet:
* A new AD Domain Controller with a root certificate authority (AD CS) and AD FS configured
* A SQL Server 2016
* A SharePoint 2016 farm, with 2 Server configured with 1 web application and 2 zones. Default zone is using Windows authentication and Intranet zone is using federated authentication with ADFS. Latest version of claims provider [LDAPCP](https://ldapcp.codeplex.com/) is installed and configured.

It also provisions a key vault to store passwords and SharePoint passphrase.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDovives%2FAzure%2Fmaster%2FAzureRM-Templates%2FIaaS%2FSP16Farm-4VM-NHA-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FDovives%2FAzure%2Fmaster%2FAzureRM-Templates%2FIaaS%2FSP16Farm-4VM-NHA-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

