configuration ConfigureSQLVM
{
    param
    (
        [Parameter(Mandatory)] [String]$DNSServer,
        [Parameter(Mandatory)] [String]$DomainFQDN,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$DomainAdminCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SqlSvcCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSetupCreds
    )

    Import-DscResource -ModuleName ComputerManagementDsc, NetworkingDsc, ActiveDirectoryDsc, SqlServerDsc, xPSDesiredStateConfiguration

    WaitForSqlSetup
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter| Where-Object Name -Like "Ethernet*"| Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [PSCredential] $DomainAdminCredsQualified = New-Object PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [PSCredential] $SPSetupCredsQualified = New-Object PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [PSCredential] $SQLCredsQualified = New-Object PSCredential ("${DomainNetbiosName}\$($SqlSvcCreds.UserName)", $SqlSvcCreds.Password)
    $ComputerName = Get-Content env:computername

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Initialization of VM
        #**********************************************************
        WindowsFeature ADTools  { Name = "RSAT-AD-Tools";      Ensure = "Present"; }
        WindowsFeature ADPS     { Name = "RSAT-AD-PowerShell"; Ensure = "Present"; }
        DnsServerAddress DnsServerAddress { Address = $DNSServer; InterfaceAlias = $InterfaceAlias; AddressFamily  = 'IPv4' }

        #**********************************************************
        # Join AD forest
        #**********************************************************
        WaitForADDomain DscForestWait
        {
            DomainName              = $DomainFQDN
            WaitTimeout             = 600
            RestartCount            = 2
            WaitForValidCredentials = $True
            Credential              = $DomainAdminCredsQualified
            DependsOn               = "[DnsServerAddress]DnsServerAddress"
        }

        Computer DomainJoin
        {
            Name = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[WaitForADDomain]DscForestWait"
        }

        #**********************************************************
        # Create accounts and configure SQL Server
        #**********************************************************
        ADUser CreateSqlSvcAccount
        {
            DomainName = $DomainFQDN
            UserName = $SqlSvcCreds.UserName
            Password = $SQLCredsQualified
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[Computer]DomainJoin"
        }

        ADServicePrincipalName UpdateSqlSPN1
        {
            Ensure               = "Present"
            ServicePrincipalName = "MSSQLSvc/$ComputerName.$($DomainFQDN):1433"
            Account              = $SqlSvcCreds.UserName
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSqlSvcAccount"
        }

        ADServicePrincipalName UpdateSqlSPN2
        {
            Ensure               = "Present"
            ServicePrincipalName = "MSSQLSvc/$ComputerName.$DomainFQDN"
            Account              = $SqlSvcCreds.UserName
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSqlSvcAccount"
        }

        ADServicePrincipalName UpdateSqlSPN3
        {
            Ensure               = "Present"
            ServicePrincipalName = "MSSQLSvc/$($ComputerName):1433"
            Account              = $SqlSvcCreds.UserName
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSqlSvcAccount"
        }

        ADServicePrincipalName UpdateSqlSPN4
        {
            Ensure               = "Present"
            ServicePrincipalName = "MSSQLSvc/$ComputerName"
            Account              = $SqlSvcCreds.UserName
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSqlSvcAccount"
        }

        SqlServiceAccount SetSqlInstanceServiceAccount
        {
            ServerName     = $ComputerName
            InstanceName   = "MSSQLSERVER"
            ServiceType    = "DatabaseEngine"
            ServiceAccount = $SQLCredsQualified
            RestartService = $true
            DependsOn      = "[ADServicePrincipalName]UpdateSqlSPN1", "[ADServicePrincipalName]UpdateSqlSPN2", "[ADServicePrincipalName]UpdateSqlSPN3", "[ADServicePrincipalName]UpdateSqlSPN4"
        }

        ADUser CreateSPSetupAccount
        {
            DomainName = $DomainFQDN
            UserName = $SPSetupCreds.UserName
            Password = $SPSetupCredsQualified
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[Computer]DomainJoin"
        }

        SqlLogin AddDomainAdminLogin
        {
            Name = "${DomainNetbiosName}\$($DomainAdminCreds.UserName)"
            Ensure = "Present"
            ServerName = $ComputerName
            InstanceName = "MSSQLSERVER"
            LoginType = "WindowsUser"
            DependsOn = "[Computer]DomainJoin"
        }

        SqlLogin AddSPSetupLogin
        {
            Name = "${DomainNetbiosName}\$($SPSetupCreds.UserName)"
            Ensure = "Present"
            ServerName = $ComputerName
            InstanceName = "MSSQLSERVER"
            LoginType = "WindowsUser"
            DependsOn = "[ADUser]CreateSPSetupAccount"
        }

        SqlRole GrantSQLRoleSysadmin
        {
            ServerRoleName = "sysadmin"
            MembersToInclude = "${DomainNetbiosName}\$($DomainAdminCreds.UserName)"
            Ensure = "Present"
            ServerName = $ComputerName
            InstanceName = "MSSQLSERVER"
            DependsOn = "[SqlLogin]AddDomainAdminLogin"
        }

        SqlRole GrantSQLRoleSecurityAdmin
        {
            ServerRoleName = "securityadmin"
            MembersToInclude = "${DomainNetbiosName}\$($SPSetupCreds.UserName)"
            ServerName = $ComputerName
            InstanceName = "MSSQLSERVER"
            Ensure = "Present"
            DependsOn = "[SqlLogin]AddSPSetupLogin"
        }

        SqlRole GrantSQLRoleDBCreator
        {
            ServerRoleName = "dbcreator"
            MembersToInclude = "${DomainNetbiosName}\$($SPSetupCreds.UserName)"
            ServerName = $ComputerName
            InstanceName = "MSSQLSERVER"
            Ensure = "Present"
            DependsOn = "[SqlLogin]AddSPSetupLogin"
        }

        SqlMaxDop ConfigureMaxDOP
        {
            ServerName   = $ComputerName
            InstanceName = "MSSQLSERVER"
            MaxDop       = 1
            DependsOn    = "[Computer]DomainJoin"
        }

        # Open port on the firewall when everything is ready, as SharePoint DSC is testing it to start creation of the farm
        Firewall DatabaseEngineFirewallRule
        {
            Direction   = "Inbound"
            Name        = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Group       = "SQL Server"
            Enabled     = "True"
            Protocol    = "TCP"
            LocalPort   = "1433"
            Ensure      = "Present"
        }
    }
}

function Get-NetBIOSName
{
    [OutputType([string])]
    param(
        [string]$DomainFQDN
    )

    if ($DomainFQDN.Contains('.')) {
        $length=$DomainFQDN.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainFQDN.Substring(0,$length)
    }
    else {
        if ($DomainFQDN.Length -gt 15) {
            return $DomainFQDN.Substring(0,15)
        }
        else {
            return $DomainFQDN
        }
    }
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}



<#
# Azure DSC extension logging: C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.21.0.0
# Azure DSC extension configuration: C:\Packages\Plugins\Microsoft.Powershell.DSC\2.21.0.0\DSCWork
Install-Module -Name SqlServerDsc

help ConfigureSQLVM
$DomainAdminCreds = Get-Credential -Credential "yvand"
$SqlSvcCreds = Get-Credential -Credential "sqlsvc"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$DNSServer = "10.0.1.4"
$DomainFQDN = "contoso.local"

ConfigureSQLVM -DNSServer $DNSServer -DomainFQDN $DomainFQDN -DomainAdminCreds $DomainAdminCreds -SqlSvcCreds $SqlSvcCreds -SPSetupCreds $SPSetupCreds -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

#>