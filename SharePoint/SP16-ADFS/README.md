# AzureRM template for SharePoint 2016 with ADFS
## Description
Provision from scratch a ready-to-use 3VMs SharePoint 2016 environment with following features:

* DC: Domain controller of a new AD forest running a root certification authority and ADFS
* SQL: Running SQL Server 2016
* SharePoint: Single SharePoint 2016 server, configured to use federated authentication with ADFS installed on DC and running claims provider [LDAPCP](https://ldapcp.codeplex.com/).

## Changelog
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
* SharePointDsc modules does not support yet the extension of the web application, so it must be done manually.
* SharePointDsc modules does not support yet to set a web application zone to use federated authentication, so it must be done manually.
* SP VM does not have permission "Enroll" in WebServer template to submit a certificate request with this template, so this permission must be granted tp "SP$" before certificate request for HTTPS web site can be submitted.
* DNS CName record "spsites" is not created, so it must be done manually.
