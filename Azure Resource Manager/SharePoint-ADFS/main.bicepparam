using './main.bicep'

param sharePointVersion = 'Subscription-Latest'
// param sharePointVersion = '2016'
param frontEndServersCount = 0
param adminUsername = 'yvand'
param outboundAccessMethod = 'PublicIPAddress'
// param outboundAccessMethod = 'AzureFirewallProxy'
param addNameToPublicIpAddresses = 'SharePointVMsOnly'
param rdpTrafficRule = 'No'
param enableAzureBastion = true
param enableHybridBenefitServerLicenses = true
param _artifactsLocation = 'https://raw.githubusercontent.com/Yvand/AzureRM-Templates/refs/heads/dev/Azure%20Resource%20Manager/SharePoint-ADFS/'
param domainFqdn = 'contoso.local'
param timeZone = 'Romance Standard Time'
param autoShutdownTime = '1900'
param vmDcSize = 'Standard_B2als_v2'
param vmSqlSize = 'Standard_B2as_v2'
param vmSharePointSize = 'Standard_B4as_v2'
param vmDcStorage = 'StandardSSD_LRS'
param vmSqlStorage = 'StandardSSD_LRS'
param vmSharePointStorage = 'StandardSSD_LRS'
param adminPassword =  'PLACEHOLDER'
param otherAccountsPassword =  'PLACEHOLDER'
