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
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SqlSvcCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupCreds,
        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
        [Int]$RetryCount=5,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xSQLServer

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($AdminCreds.UserName)", $AdminCreds.Password)
    [System.Management.Automation.PSCredential]$SPSCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlSvcCreds.UserName)", $SqlSvcCreds.Password)

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

        xADUser CreateSqlSvcAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SqlSvcCreds.UserName
            Password = $SQLCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
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

        xSQLServerLogin AddDomainAdminLogin
        {
            Name = "${DomainNetbiosName}\$($AdminCreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            LoginType = "WindowsUser"
            DependsOn = "[xComputer]DomainJoin"
        }

        xSQLServerLogin AddSPSetupLogin
        {
            Name = "${DomainNetbiosName}\$($SPSetupCreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            LoginType = "WindowsUser"
            DependsOn = "[xADUser]CreateSPSetupAccount"
        }

        xSQLServerRole GrantDomainAdminSQLRoles
        {
            Name = "${DomainNetbiosName}\$($AdminCreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            ServerRole = "sysadmin"
            DependsOn = "[xSQLServerLogin]AddDomainAdminLogin"
        }

        xSQLServerRole GrantSPSetupSQLRoles
        {
            Name = "${DomainNetbiosName}\$($SPSetupCreds.UserName)"
            Ensure = "Present"
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            ServerRole = "securityadmin","dbcreator"
            DependsOn = "[xSQLServerLogin]AddSPSetupLogin"
        }

        xSQLServerMaxDop ConfigureMaxDOP
        {
            SQLServer = $env:COMPUTERNAME
            SQLInstanceName = "MSSQLSERVER"
            MaxDop = 1
            DependsOn = "[xComputer]DomainJoin"
        }

        <#
        xSQLServerSetup ConfigureSQLServer
        {
            SetupCredential = $AdminCreds
            InstanceName = "MSSQLSERVER"
            SQLUserDBDir = "F:\DATA"
            SQLUserDBLogDir = "G:\LOG"
        }
        #>
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
help ConfigureSQLVM
$AdminCreds = Get-Credential -Credential "yvand"
$SqlSvcCreds = Get-Credential -Credential "sqlsvc"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$DomainName = "contoso.local"

ConfigureSQLVM -DomainName $DomainName -AdminCreds $AdminCreds -SqlSvcCreds $SqlSvcCreds -SPSetupCreds $SPSetupCreds -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

#>
