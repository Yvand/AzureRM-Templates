<#
.SYNOPSIS
This script installs and deploys a custom claims provider in the SharePoint farm
 
.PARAMETER pathToPackage
   The full path to the claims provider WSP package.
.PARAMETER claimsProviderName
   The name of the claims provider.
.PARAMETER spTrustName
   The name of the SPTrusedLoginProvider.
.PARAMETER adminUserName
   The name of SharePoint admin account that will install the claims provider.
.PARAMETER adminPassword
   The password of SharePoint admin account.
 
.NOTES
The script assumes that the claims provider WSP package exists, and that it is not already installed.
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="The full path to the claims provider WSP package.")]
    [string] $pathToPackage,
    [Parameter(Mandatory=$true, HelpMessage="The name of the claims provider.")]
    [string] $claimsProviderName,
    [Parameter(Mandatory=$true, HelpMessage="The name of the SPTrusedLoginProvider.")]
    [string] $spTrustName,
    [Parameter(Mandatory=$true, HelpMessage="The name of SharePoint admin account that will install the claims provider.")]
    [string] $adminUserName,
    [Parameter(Mandatory=$true, HelpMessage="The password of SharePoint admin account.")]
    [string] $adminPassword
)

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

try
{
    Import-Module -Name ".\ConfigureLab.psm1"
    Configure-Lab @PSBoundParameters
}
catch
{
    $errorMessage = $_.Exception.Message
    Write-Host "Configuration of the lab failed with error $errorMessage. $($_.Exception)" -ForegroundColor Red
}
finally
{
    Pop-Location
	Remove-Module -Name "ConfigureLab"
}
