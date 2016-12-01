Configuration ConfigureSQLReplica
{
    param (
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $DomainAdminCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $AdminCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SQLServiceCredential,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSetupUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $SQLPort,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $NumberOfDataDisks,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $NumberOfLogDisks
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSQL
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

        xSqlTsqlEndpoint CreateSQLServerEndPoint
        {
            InstanceName = "MSSQLSERVER"
            PortNumber = $SQLPort
            SqlAdministratorCredential = $SQLServiceCredential
            DependsOn = "[xSqlLogin]AddSQLServiceAccountToSQL"
        }

        xSqlServer ConfigureSql
        {
            InstanceName = $env:COMPUTERNAME
            SqlAdministratorCredential = $SQLServiceCredential
            ServiceCredential = $SQLServiceCredential
            MaxDegreeOfParallelism = 1
            FilePath = "F:\DATA"
            LogPath = "G:\LOG"
            DomainAdministratorCredential = $DomainAdminCredential
            DependsOn = @("[xSqlTsqlEndpoint]CreateSQLServerEndPoint")
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