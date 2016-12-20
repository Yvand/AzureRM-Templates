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
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SqlServerServiceAccountcreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,
        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xSQLServer

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SPSCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlServerServiceAccountcreds.UserName)", $SqlServerServiceAccountcreds.Password)

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

        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SqlServerServiceAccountcreds.UserName
            Password = $SQLCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSharePointSetupAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SharePointSetupUserAccountcreds.UserName
            Password = $SPSCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xSQLServerRole AddDomainAdminAccountToSysadminServerRole
        {
            Name = "${DomainNetbiosName}\$($Admincreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            ServerRole = "sysadmin"
            DependsOn = "[xComputer]DomainJoin"
        }

        xSQLServerRole ConfigureSharePointSetupAccountSqlLogin
        {
            Name = "${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            ServerRole = "securityadmin","dbcreator"
            DependsOn = "[xADUser]CreateSharePointSetupAccount"
        }

        xSQLServerMaxDop ConfigureMaxDOP
        {
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            MaxDop = 1
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
$Admincreds = Get-Credential -Credential "yvand"
$SqlServerServiceAccountcreds = Get-Credential -Credential "sqlsvc"
$SharePointSetupUserAccountcreds = Get-Credential -Credential "spsetup"
$DomainName = "contoso.local"

ConfigureSqlServer -DomainName $DomainName -Admincreds $Admincreds -SqlServerServiceAccountcreds $SqlServerServiceAccountcreds -SharePointSetupUserAccountcreds $SharePointSetupUserAccountcreds -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\Dev\output"
help ConfigureSqlServer

Start-DscConfiguration -Path "C:\Data\Dev\output" -Wait -Verbose -Force
#>
