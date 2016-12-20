#
# Copyright="Microsoft Corporation. All rights reserved."
#

configuration PrepareSqlServer
{

    param
    (
        [Parameter(Mandatory)]
        [String]$DNSServer,
        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xComputerManagement, xNetworking, xDisk,cDisk
    WaitForSqlSetup
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
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

