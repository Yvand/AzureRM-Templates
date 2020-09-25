# Change log for Terraform template SharePoint-ADFS-Terraform

## ## Enhancements & bug-fixes - Published in September 25, 2020

* Fix many problems in the template that was outdated
* It's now possible to add 0 to n FE VM by setting var countOfFrontEndToAdd (which replaces addFrontEndToFarm)
* Upgrade to Terraform v0.13
* Update azurerm to v2.28

## October 2019 update

* Convert to new language introduced in v0.12
* Replace SQL Server 2016 with SQL Server 2017
* Use SQL Server Developer edition instead of Standard edition. More info: <https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sql/virtual-machines-windows-sql-server-pricing-guidance>
* Update DC to run with Windows Server 2019

## November 2018

* Initial release
