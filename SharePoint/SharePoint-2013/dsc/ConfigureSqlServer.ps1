#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration ConfigureSqlServer
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

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xSql, xSQLServer, xSQLps

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
            DomainUserCredential= $Admincreds
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

        xSqlServer ConfigureSqlServer
        {
            InstanceName = $env:COMPUTERNAME
            SqlAdministratorCredential = $Admincreds
            ServiceCredential = $SQLCreds
            MaxDegreeOfParallelism = 1
            FilePath = "F:\DATA"
            LogPath = "G:\LOG"
            DomainAdministratorCredential = $DomainCreds
            DependsOn = "[xADUser]CreateSqlServerServiceAccount"

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


        xSqlLogin AddDomainAdminAccountToSysadminServerRole
        {
            Name = "${DomainNetbiosName}\$($Admincreds.UserName)"
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $Admincreds
            DependsOn = "[xSqlServer]ConfigureSqlServer"
        }

        xSqlLogin ConfigureSharePointSetupAccountSqlLogin
        {
            Name = "${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)"
            LoginType = "WindowsUser"
            ServerRoles = "securityadmin","dbcreator"
            Enabled = $true
            Credential = $ADmincreds
            DependsOn = "[xADUser]CreateSharePointSetupAccount","[xSqlServer]ConfigureSqlServer"
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

