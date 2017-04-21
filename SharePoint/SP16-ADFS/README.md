# AzureRM template for SharePoint 2016 with ADFS
## Description
This template deploys 3 new Azure VMs, each with its own public IP address and subnet:
* A new AD Domain Controller with a root certificate authority (AD CS) and AD FS configured
* A SQL Server 2016
* A SharePoint 2016 standalone farm, configured with 1 web application and 2 zones. Default zone is using Windows authentication and Intranet zone is using federated authentication with ADFS. Latest version of claims provider [LDAPCP](https://ldapcp.codeplex.com/) is installed and configured.

It also provisions a key vault to store passwords and SharePoint passphrase.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FSharePoint%2FSP16-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FSharePoint%2FSP16-ADFS%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Changelog
### March 2017 v3 release
* Azure key vault and its secrets are now created by the deployment script itself, removing the dependency to the PowerShell deployment script
* Removed nested templates

### March 2017 v2 release
* Optimizations in PowerShell deployment script
* Parameters that must be unique in Azure were moved to parameters file and are no more set with a default value
* SP: Many improvements in DSC
* SP: DSC extends the web application with a HTTPS URL for federated authentication, creates DNS alias for intranet sites, sets the HTTPS certificate in IIS and sets ADFS administrator on each site collection
* Updated xCertificate module

### March 2017 release
* DC: DSC fully creates ADFS farm and add a relying party. It also exports signing certificate and signing certificate issuer in file system
* SP: DSC copies signing certificate and signing certificate issuer from DC to a local path, and uses it to create a SPLoginProvider object and establish trust relationship between SharePoint and DC
* SP: DSC populates more sites collections in web application
* SP: Use a custom version of SharePointDsc (from version 1.5.0.0) to update SPTrustedIdentityTokenIssuer resource to get signing certificate from file system. I started a [pull request](https://github.com/PowerShell/SharePointDsc/pull/520) to push those changes in standard module.
* Updated xNetworking to version 3.2.0.0
* Minor updates to clean code, improve consistency and make some settings working fine when they are not using default value (e.g. name of DC VM).

### February 2017 release
* Azure template now uses Azure Key Vault to store and use passwords, which forced the use of netsted templates to allow it to be dynamic
* Updated xActiveDirectory to version 2.16.0.0, which fixed the AD domain creation issue on Azure
 
## Known issues or limitations
### On SQL VM
* SQL DSC module currently doesn't allow to change location of log/data files, so all SQL data/log files are created in their default folders.

### On SharePoint VM
* Download of 2016-12 CU from download.microsoft.com randomly fails, causing the whole SharePoint configuration to fail, so it is disabled until a reliable solution is found.

