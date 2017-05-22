# AzureRM template for SharePoint 2016 with ADFS and Two SP VM
## Description
This template deploys 4 new Azure VMs, each with its own public IP address and subnet:
* A new AD Domain Controller with a root certificate authority (AD CS) and AD FS configured
* A SQL Server 2016
* A SharePoint 2016 farm, with 2 Server configured with 1 web application and 2 zones. Default zone is using Windows authentication and Intranet zone is using federated authentication with ADFS. Latest version of claims provider [LDAPCP](https://ldapcp.codeplex.com/) is installed and configured.

It also provisions a key vault to store passwords and SharePoint passphrase.
It is very similar and synced with [this template](https://github.com/Yvand/AzureRM-Templates/tree/master/SharePoint/SP16-ADFS), but it deploys 2 SharePoint VMs instead of 1.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2FYvand%2FAzureRM-Templates%2Fraw%2Fmaster%2FSharePoint%2FSP16-ADFS-MultVMs%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fgithub.com%2FYvand%2FAzureRM-Templates%2Fraw%2Fmaster%2FSharePoint%2FSP16-ADFS-MultVMs%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Changelog
### May 2017 release
* Initial release

## Known issues or limitations
### On SQL VM
* SQL DSC module currently doesn't allow to change location of log/data files, so all SQL data/log files are created in their default folders.

### On SharePoint VM
* Download of 2016-12 CU from download.microsoft.com randomly fails, causing the whole SharePoint configuration to fail, so it is disabled until a reliable solution is found.
