---
description: This template creates a SharePoint Subscription / 2019 / 2016 farm with an extensive configuration that would take ages to perform manually, including a federated authentication with ADFS, an OAuth trust, the User Profiles service and a web application with 2 zones that contains multiple path based and host-named site collections. On the SharePoint virtual machines, Chocolatey is used to install the latest version of Notepad++, Visual Studio Code, Azure Data Studio, Fiddler, ULS Viewer and 7-Zip.
page_type: sample
products:
- azure
- azure-resource-manager
urlFragment: sharepoint-adfs
languages:
- json
---
# SharePoint Subscription / 2019 / 2016 all configured

## Deploy the template

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FYvand%2FAzureRM-Templates%2Fmaster%2FTemplates%2FSharePoint-ADFS%2Fazuredeploy.json)

> **Note:** A public version of this template is available at <https://azure.microsoft.com/resources/templates/sharepoint-adfs/>

## Features

This template creates a DC, a SQL Server 2022, and from 1 to 5 server(s) hosting a SharePoint Subscription / 2019 / 2016 farm with an extensive configuration, including trusted authentication, user profiles with personal sites, an OAuth trust (using a certificate), a dedicated IIS site for hosting high-trust add-ins, etc...  
The latest version of key softwares (including Fiddler, vscode, np++, 7zip, ULS Viewer) is installed.  
SharePoint machines have additional fine-tuning to make them immediately usable (remote administration tools, custom policies for Edge and Chrome, shortcuts, etc...).

There are some differences in the configuration, depending on the SharePoint version:

### Common to all SharePoint versions

- An Active Directory forest with AD CS and AD FS configured. LDAPS (LDAP over SSL) is also configured.
- SharePoint service applications configured: User Profiles, add-ins, session state.
- SharePoint User Profiles service is configured with a directory synchronization connection, and the MySite host is a host-named site collection.
- SharePoint has 1 web application with path based and host-named site collections, and contains 2 zones:
  - Default zone: HTTP using Windows authentication.
  - Intranet zone: HTTPS using federated (ADFS) authentication.
- An OAuth trust is created, as well as a custom IIS site to host your high-trust add-ins.
- Custom claims provider [LDAPCP](https://www.ldapcp.com/) is installed and configured.

### Specific to SharePoint Subscription

- SharePoint virtual machines are created using the latest disk image of [Windows Server 2022 Azure Edition](https://learn.microsoft.com/windows-server/get-started/editions-comparison-windows-server-2022) available, and SharePoint binaries (install + cumulative updates) are downloaded and installed from scratch.
- The HTTPS site certificate is managed by SharePoint, which has the private key and sets the binding itself in the IIS site.
- Federated authentication with ADFS is configured using OpenID Connect.

### Specific to SharePoint 2019 / 2016

- SharePoint virtual machines are created using a disk image built and maintained by SharePoint Engineering.
- The HTTPS site certificate is positioned by the DSC script.
- Federated authentication with ADFS is configured using SAML 1.1.

## Key parameters

### Input parameters

- parameter `sharePointVersion` lets you choose which version of SharePoint to install:
  - `Subscription-Latest` (default): Same as `Subscription-RTM`, then installs the latest cumulative update available at the time of publishing this version: September 2024 ([kb5002640](https://support.microsoft.com/help/5002640)).
  - `Subscription-24H2`: Same as `Subscription-RTM`, then installs the [Feature Update 24H2](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-24h2-release) (September 2024 CU / [kb5002640](https://support.microsoft.com/help/5002640)).
  - `Subscription-24H1`: Same as `Subscription-RTM`, then installs the [Feature Update 24H1](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-24h1-release) (March 2024 CU / [KB5002564](https://support.microsoft.com/help/5002564)).
  - `Subscription-23H2`: Same as `Subscription-RTM`, then installs the [Feature Update 23H2](https://learn.microsoft.com/en-us/SharePoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-23h2-release) (September 2023 CU / [KB5002474](https://support.microsoft.com/help/5002474)).
  - `Subscription-23H1`: Same as `Subscription-RTM`, then installs the [Feature Update 23H1](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-23h1-release) (March 2023 CU / [KB5002355](https://support.microsoft.com/help/5002355)).
  - `Subscription-22H2`: Same as `Subscription-RTM`, then installs the [Feature Update 22H2](https://learn.microsoft.com/en-us/sharepoint/what-s-new/new-and-improved-features-in-sharepoint-server-subscription-edition-22h2-release) (September 2022 CU / [KB5002270](https://support.microsoft.com/help/5002270) and [KB5002271](https://support.microsoft.com/help/5002271)).
  - `Subscription-RTM`: Uses a fresh Windows Server 2022 image, on which SharePoint Subscription RTM is downloaded and installed.
  - `2019`: Uses an image built and maintained by SharePoint Engineering, with SharePoint 2019 bits already installed.
  - `2016`: Uses an image built and maintained by SharePoint Engineering, with SharePoint 2016 bits already installed.
- parameters `outboundAccessMethod` and `rdpTrafficRule`: See [this section](#remote-access-and-security) for detailed information.
- parameter `frontEndServersCount` lets you add up to 4 additional SharePoint servers to the farm with the [MinRole Front-end](https://learn.microsoft.com/en-us/sharepoint/install/planning-for-a-minrole-server-deployment-in-sharepoint-server).
- parameter `enableHybridBenefitServerLicenses` allows you to enable Azure Hybrid Benefit to use your on-premises Windows Server licenses and reduce cost, if you are eligible. See [this page](https://docs.microsoft.com/azure/virtual-machines/windows/hybrid-use-benefit-licensing) for more information..
- Parameters `adminPassword` and `otherAccountsPassword` require a [strong password](https://learn.microsoft.com/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-).

### Output parameters

The template returns multiple variables to record the logins, passwords and the public IP address of virtual machines.

## Remote access and security

The options for the remote access and the security of the virtual machines is determined by the following parameters:

- Parameter `outboundAccessMethod` specifies how the virtual machines connect to internet:
    - `PublicIPAddress`: Using a Public IP resource, added to each virtual machine. The DNS name format of virtual machines is `"[resourceGroupName]-[vm_name].[region].cloudapp.azure.com"` and is recorded as an output.
    - `AzureFirewallProxy`: Using Azure Firewall as an HTTP proxy IMPORTANT: You need to either enable Azure Bastion, or manually add a public IP address to a virtual machine, to be able to connect to it.
- Parameter `rdpTrafficRule` specifies if a rule in the network security groups should allow the inbound RDP traffic:
    - `No` (default): No rule is created, RDP traffic is blocked.
    - `*` or "Internet": RDP traffic is allowed from everywhere.
    - CIDR notation (e.g. `192.168.99.0/24` or `2001:1234::/64`) or an IP address (e.g. `192.168.99.0` or `2001:1234::`): RDP traffic is allowed from the IP address / pattern specified.
- parameter `enableAzureBastion`:
  - if `true`: Configure service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) to allow a secure remote access to virtual machines.
  - if `false` (default): Service [Azure Bastion](https://azure.microsoft.com/services/azure-bastion/) is not created.

## Cost of the resources deployed

By default, virtual machines use [B-series burstable](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable), ideal for such template and much cheaper than other comparable series.  
Here is the default size and storage type per virtual machine role:

- DC: Size [Standard_B2s](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 4 GiB RAM) and OS disk is a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SQL Server: Size [Standard_B2ms](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (2 vCPU / 8 GiB RAM) and OS disk is a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds).
- SharePoint: Size [Standard_B4ms](https://docs.microsoft.com/azure/virtual-machines/sizes-b-series-burstable) (4 vCPU / 16 GiB RAM) and OS disk is either a 32 GiB [standard SSD E4](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint Subscription and 2019), or a 128 GiB [standard SSD E10](https://learn.microsoft.com/azure/virtual-machines/disks-types#standard-ssds) (for SharePoint 2016).

You can visit <https://azure.com/e/c494029b0b034b8ca356c926dfd2688a> to estimate the monthly cost of the template in the region/currency of your choice, assuming it is created using the default settings and runs 24*7.

## Known issues

- The password of the directory synchronization connection (set in parameter `serviceAccountsPassword`) needs to be re-entered in the "Edit synchronization connection" page, otherwise SharePoint is somehow unable to decrypt it and the import fails.

## More information

Additional notes:

- Using the default options, the complete deployment takes about 1h (but it is worth it).
- Deploying any post-RTM SharePoint Subscription build adds only an extra 5-10 minutes to the total deployment time (compared to RTM), partly because the updates are installed before the farm is created.
- Once it is completed, the template will return valuable information in the 'Outputs' of the deployment.
- For various (very good) reasons, in SQL and SharePoint VMs, the name of the local (not domain) administrator is set with a string that is unique to your subscription (e.g. `"local-[q1w2e3r4t5]"`). It is recorded in the 'Outputs' of the deployment once it is completed.

`Tags: Microsoft.Network/networkSecurityGroups, Microsoft.Network/virtualNetworks, Microsoft.Network/publicIPAddresses, Microsoft.Network/networkInterfaces, Microsoft.Compute/virtualMachines, extensions, DSC, Microsoft.Compute/virtualMachines/extensions, Microsoft.DevTestLab/schedules, Microsoft.Network/virtualNetworks/subnets, Microsoft.Network/bastionHosts`
