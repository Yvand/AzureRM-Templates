configuration ConfigureSQLVM
{
    param
    (
		[Parameter(Mandatory)]
        [String]$DNSServer,

        [Parameter(Mandatory)]
        [String]$DomainFQDN,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SqlSvcCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupCreds,
        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainFQDN $DomainFQDN),
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName xComputerManagement, xNetworking, xDisk, cDisk, xActiveDirectory, xSQLServer
	
	WaitForSqlSetup
    $Interface = Get-NetAdapter| Where Name -Like "Ethernet*"| Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [PSCredential]$DomainCreds = New-Object PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [PSCredential]$SPSCreds = New-Object PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [PSCredential]$SQLCreds = New-Object PSCredential ("${DomainNetbiosName}\$($SqlSvcCreds.UserName)", $SqlSvcCreds.Password)

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
		xWaitforDisk Disk2
        {
            DiskNumber = 2
            RetryIntervalSec =$RetryIntervalSec
            RetryCount = $RetryCount
        }
        cDiskNoRestart SQLDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
	        DependsOn="[xWaitForDisk]Disk2"
        }
        xWaitforDisk Disk3
        {
            DiskNumber = 3
            RetryIntervalSec =$RetryIntervalSec
            RetryCount = $RetryCount
            DependsOn="[cDiskNoRestart]SQLDataDisk"
        }
        cDiskNoRestart SQLLogDisk
        {
            DiskNumber = 3
            DriveLetter = "G"
            DependsOn="[xWaitForDisk]Disk3"
        }
        xFirewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Group = "SQL Server"
            Enabled = "True"
            Protocol = "TCP"
            LocalPort = "1433"
            Ensure = "Present"
        }
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = "[cDiskNoRestart]SQLDataDisk","[cDiskNoRestart]SQLLogDisk"

        }
        xDnsServerAddress DnsServerAddress
        {
            Address        = $DNSServer
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn="[WindowsFeature]ADPS"
        }
        
		#**********************************************************
        # Join AD forest
        #**********************************************************
        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainFQDN
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainFQDN
            Credential = $DomainCreds
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

		#**********************************************************
        # Create accounts and configure SQL Server
        #**********************************************************
        xADUser CreateSqlSvcAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainFQDN
            UserName = $SqlSvcCreds.UserName
            Password = $SQLCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSPSetupAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainFQDN
            UserName = $SPSetupCreds.UserName
            Password = $SPSCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xSQLServerLogin AddDomainAdminLogin
        {
            Name = "${DomainNetbiosName}\$($DomainAdminCreds.UserName)"
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
            Name = "${DomainNetbiosName}\$($DomainAdminCreds.UserName)"
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
            SetupCredential = $DomainAdminCreds
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
help ConfigureSQLVM
$DomainAdminCreds = Get-Credential -Credential "yvand"
$SqlSvcCreds = Get-Credential -Credential "sqlsvc"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$DNSServer = "10.0.1.4"
$DomainFQDN = "contoso.local"

ConfigureSQLVM -DNSServer $DNSServer -DomainFQDN $DomainFQDN -DomainAdminCreds $DomainAdminCreds -SqlSvcCreds $SqlSvcCreds -SPSetupCreds $SPSetupCreds -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

#>
