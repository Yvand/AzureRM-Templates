#
# Copyright="Microsoft Corporation. All rights reserved."
#

configuration ConfigureSQLVM
{

    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$ArtifactsLocation,

        [Parameter(Mandatory)]
        [String]$ArtifactsLocationSasToken,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SqlSvcCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupCreds,
        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory

    [System.Management.Automation.PSCredential]$SPSCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        
        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xADUser CreateSPSetupAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SPSetupCreds.UserName
            Password = $SPSCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }
    }
}
function Get-NetBIOSName
{
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}



<#
$AdminCreds = Get-Credential -Credential "yvand"
$SqlSvcCreds = Get-Credential -Credential "sqlsvc"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$DomainName = "contoso.local"

ConfigureSQLVM -DomainName $DomainName -AdminCreds $AdminCreds -SqlSvcCreds $SqlSvcCreds -SPSetupCreds $SPSetupCreds -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
help ConfigureSQLVM

Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force
#>
