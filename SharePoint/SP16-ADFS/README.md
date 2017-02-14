# AzureRM template for SharePoint 2016 with ADFS
## Description
Provision from scratch a ready-to-use 3VMs SharePoint 2016 environment with following features:

* DC: Domain controller of a new AD forest running a root certification authority and ADFS
* SQL: Running SQL Server 2016
* SharePoint: 1 single SharePoint 2016 server

## Changelog
### February 2017 release
* Azure template now uses Azure Key Vault to store and use passwords, which forced the use of netsted templates to allow it to be dynamic
* Updated xActiveDirectory to version 2.16.0.0, which fixed the AD domain creation issue on Azure
 
## Known issues
### On DC VM
* Creation of ADFS farm fails on 1st execution of DSC script, probably because the account running the script doesn't have a local profile yet, which somehow prevents it to access private keys of ADFS certificates.
 
### On SQL VM
* SQL DSC module currently doesn't allow to change location of log/data files

### On SharePoint VM
* Download of CU from download.microsoft.com randomly fails, causing the SharePoint configuration to fail, so it is disabled until a reliable solution is found
