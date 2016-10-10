Configuration ConfigureSQLAOCluster
{
    param (
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $DomainAdminCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $AdminCredential,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SQLServiceCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSetupUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLClusterName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $FSWSharePath,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLPrimaryReplica,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLSecondaryReplica,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLAOEndPointName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLAOAvailabilityGroupName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLAOListenerName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLLBName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLLBIPAddress,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $SQLPort,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $NumberOfDataDisks,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $NumberOfLogDisks,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DNSServerName,
        [string]                                                               $DatabaseNames = "PLAAOTestDB"
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName xSQL
    Import-DscResource -ModuleName xDnsServer
    Import-DscResource -ModuleName xSPPLA

    WaitForSqlSetup  
      
    node "localhost"
    {
        #**********************************************************
        # Add Data and Log Disks
        #********************************************************** 
        xSPPLACreateVirtualDisk SQLDataVirtualDisk
        {
            StoragePoolName = "SQLDataStoragePool"
            VirtualDiskName = "SQLData"
            NumberOfDisks = $NumberOfDataDisks
            DriveLetter = "F"
            RebootVirtualMachine = $false
        }

        xSPPLACreateVirtualDisk SQLLogVirtualDisk
        {
            StoragePoolName = "SQLLogStoragePool"
            VirtualDiskName = "SQLLog"
            NumberOfDisks = $NumberOfLogDisks
            DriveLetter = "G"
            RebootVirtualMachine = $false
            DependsOn = "[xSPPLACreateVirtualDisk]SQLDataVirtualDisk"
        }

        #**********************************************************
        # Join Domain
        #********************************************************** 
        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainAdminCredential
            DependsOn = "[xSPPLACreateVirtualDisk]SQLLogVirtualDisk"
        }
        
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xComputer]DomainJoin" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $CredSSPDelegates; DependsOn = "[xComputer]DomainJoin" }
        
        #**********************************************************
        # Enable Cluster Features
        #********************************************************** 
        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FC"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FCPS"
        }

        WindowsFeature DSNTools
        {
            Name = "RSAT-DNS-Server"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FC"
        }

        #**********************************************************
        # Add SQL Firewall Rules
        #********************************************************** 
        xFirewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Group = "SQL Server"
            Enabled = $true
            Action = "Allow"
            Protocol = "TCP"
            LocalPort = $SQLPort.ToString()
            Ensure = "Present"
        }

        xFirewall DatabaseMirroringFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Mirroring-TCP-In"
            DisplayName = "SQL Server Database Mirroring (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring."
            Group = "SQL Server"
            Enabled = "True"
            Action = "Allow"
            Protocol = "TCP"
            LocalPort = "5022"
            Ensure = "Present"
        }

        xFirewall ListenerFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Availability-Group-Listener-TCP-In"
            DisplayName = "SQL Server Availability Group Listener (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Availability Group listener."
            Group = "SQL Server"
            Enabled = "True"
            Action = "Allow"
            Protocol = "TCP"
            LocalPort = "59999"
            Ensure = "Present"
        }

        #**********************************************************
        # Add SP Setup Account and SQL Service Account to admin group
        #********************************************************** 
        Group AddInstallAccountToAdminGroup
        {
            GroupName='Administrators'   
            Ensure= 'Present'             
            MembersToInclude= @($SPSetupUsername, $SQLServiceCredential.UserName)
            Credential = $DomainAdminCredential
            PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[xComputer]DomainJoin"
        }

        #**********************************************************
        # Add SetupAccount to the SQL - DBCreator and Security Admins
        #********************************************************** 
        xSqlLogin AddSPSetupAccountToSQL
        {
            Name = $SPSetupUsername
            LoginType = "WindowsUser"
            ServerRoles = @("securityadmin", "dbcreator")
            Enabled = $true
            Credential = $AdminCredential
            DependsOn = "[xComputer]DomainJoin"
        }

        #**********************************************************
        # Add DomainAdmin Account to the SQL - Sys Admin
        #********************************************************** 
        xSqlLogin AddDomainAdminAccountToSQL
        {
            Name = $DomainAdminCredential.UserName
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $AdminCredential
            DependsOn = "[xComputer]DomainJoin"
        }

        xSqlLogin AddSQLServiceAccountToSQL
        {
            Name = $SQLServiceCredential.UserName
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $AdminCredential
            DependsOn = "[xComputer]DomainJoin"
        }

        xSqlTsqlEndpoint AddSqlServerEndpoint
        {
            InstanceName = "MSSQLSERVER"
            PortNumber = $SQLPort
            SqlAdministratorCredential = $SQLServiceCredential
            DependsOn = "[xSqlLogin]AddSQLServiceAccountToSQL"
        }

        xCluster CreateFailoverCluster
        {
            Name                          = $SQLClusterName
            Nodes                         = @($SQLPrimaryReplica, $SQLSecondaryReplica)
            DomainAdministratorCredential = $DomainAdminCredential
        }

        xWaitForFileShareWitness WaitForFSW
        {
            SharePath = $FSWSharePath
            DomainAdministratorCredential = $DomainAdminCredential
            DependsOn="[xCluster]CreateFailoverCluster"
            RetryIntervalSec = 20
            RetryCount = 20
        }

        xClusterQuorum CreateClusterQuorum
        {
            Name = $SQLClusterName
            SharePath = $FSWSharePath
            DomainAdministratorCredential = $DomainAdminCredential
            DependsOn="[xWaitForFileShareWitness]WaitForFSW"
        }

        xSqlServer ConfigurePrimaryServerWithAlwaysOn
        {
            InstanceName = $env:COMPUTERNAME
            SqlAdministratorCredential = $SQLServiceCredential
            ServiceCredential = $SQLServiceCredential
            Hadr = "Enabled"
            MaxDegreeOfParallelism = 1
            FilePath = "F:\DATA"
            LogPath = "G:\LOG"
            DomainAdministratorCredential = $DomainAdminCredential
            DependsOn = "[xClusterQuorum]CreateClusterQuorum"
        }

        xSQLAddListenerIPToDNS AddLoadBalancer
        {
            LBName = $SQLLBName
            Credential = $DomainAdminCredential
            LBAddress = $SQLLBIPAddress
            DNSServerName = $DNSServerName
            DomainName = $DomainName
            DependsOn = "[xSqlServer]ConfigurePrimaryServerWithAlwaysOn"
        }

        xSqlEndpoint CreatePrimaryAlwaysOnEndpoint
        {
            InstanceName = $env:COMPUTERNAME
            Name = $SQLAOEndPointName
            PortNumber = 5022
            AllowedUser = $SQLServiceCredential.UserName
            SqlAdministratorCredential = $SQLServiceCredential
            DependsOn = "[xSqlServer]ConfigurePrimaryServerWithAlwaysOn"
        }

        xSqlServer ConfigureSecondaryServerWithAlwaysOn
        {
            InstanceName = $SQLSecondaryReplica
            SqlAdministratorCredential = $SQLServiceCredential
            Hadr = "Enabled"
            DomainAdministratorCredential = $DomainAdminCredential
            DependsOn = "[xSqlServer]ConfigurePrimaryServerWithAlwaysOn"
        }

        xSqlEndpoint CreateSecondaryAlwaysOnEndpoint
        {
            InstanceName = $SQLSecondaryReplica
            Name = $SQLAOEndPointName
            PortNumber = 5022
            AllowedUser = $SQLServiceCredential.UserName
            SqlAdministratorCredential = $SQLServiceCredential
	        DependsOn="[xSqlServer]ConfigureSecondaryServerWithAlwaysOn"
        }
        
        xSqlAvailabilityGroup CreateAlwaysOnAvailabilityGroup
        {
            Name = $SQLAOAvailabilityGroupName
            ClusterName = $SQLClusterName
            InstanceName = $env:COMPUTERNAME
            PortNumber = 5022
            DomainCredential = $DomainAdminCredential
            SqlAdministratorCredential = $SQLServiceCredential
	        DependsOn="[xSqlEndpoint]CreateSecondaryAlwaysOnEndpoint"
        }
        
        xSqlNewAGDatabase CreateTempSQLAGDatabase
        {
            SqlAlwaysOnAvailabilityGroupName = $SQLAOAvailabilityGroupName
            DatabaseNames = $DatabaseNames
            PrimaryReplica = $SQLPrimaryReplica
            SecondaryReplica = $SQLSecondaryReplica
            SqlAdministratorCredential = $SQLServiceCredential
	        DependsOn = "[xSqlAvailabilityGroup]CreateAlwaysOnAvailabilityGroup"
        }

        xSqlAvailabilityGroupListener CreateListener
        {
            Name = $SQLAOListenerName
            AvailabilityGroupName = $SQLAOAvailabilityGroupName
            DomainNameFqdn = $SQLLBName + "." + $DomainName
            ListenerPortNumber = $SQLPort
            ListenerIPAddress = $SQLLBIPAddress
            ProbePortNumber = 59999
            InstanceName = $env:COMPUTERNAME
            DomainCredential = $DomainAdminCredential
            SqlAdministratorCredential = $SQLServiceCredential
            DependsOn = "[xSqlNewAGDatabase]CreateTempSQLAGDatabase"
        }

        #**********************************************************
        # Local configuration manager settings
        #
        # This section contains settings for the LCM of the host
        # that this configuraiton is applied to
        #**********************************************************
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
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