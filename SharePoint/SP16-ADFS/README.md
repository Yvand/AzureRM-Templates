# AzureRM template for SharePoint 2016 with ADFS
## Description
Provision from scratch a ready-to-use 3VMs SharePoint environment with following features:

* DC: Domain controller of a new AD forest running a root certification authority and ADFS
* SQL: Running SQL Server 2016
* SharePoint: 1 single SharePoint 2016 server
 
## Known issues
This is a work in progress, below are the known issues:
### On DC VM
* Creation of ADFS farm on 1st run of DSC script fails, probably because the account running the script doesn't have a local profile, which somehow prevents it to access private keys of ADFS certificates
 
### On SQL VM
* SQL DSC module currently doesn't allow to change location of log/data files

### On SharePoint VM
* SharePoint configuration wizard fails because of the bug in SharePoint image, details and workaround here: https://technet.microsoft.com/en-us/library/mt723354(v=office.16).aspx
