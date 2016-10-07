Configuration PrepareSQLWitnessVM
{
    param (
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $DomainAdminCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $AdminCredential,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSetupUsername,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SQLServiceUsername
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xDisk
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xSmbShare
    
    node "localhost"
    {
        #**********************************************************
        # Server configuration
        #
        # This section of the configuration includes details of the
        # server level configuration, such as disks, registry
        # settings, local admins, etc
        #********************************************************** 

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainAdminCredential
        }

        xDisk FSWDisk 
        { 
            DiskNumber = 2; 
            DriveLetter = "F"; 
            DependsOn = "[xComputer]DomainJoin" 
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = "[xDisk]FSWDisk"
        } 

        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xComputer]DomainJoin" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $CredSSPDelegates; DependsOn = "[xComputer]DomainJoin" }

        Group AddInstallAccountToAdminGroup
        {
            GroupName='Administrators'   
            Ensure= 'Present'             
            MembersToInclude= @($SPSetupUsername,$SQLServiceUsername)
            Credential = $DomainAdminCredential    
            PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[xComputer]DomainJoin"

        }

        File FSWFolder
        {
            DestinationPath = "F:\SQLWitnessShare"
            Type = "Directory"
            Ensure = "Present"
            DependsOn = "[xDisk]FSWDisk"
        }

        xSmbShare FSWShare
        {
            Name = "SQLWitnessShare"
            Path = "F:\SQLWitnessShare"
            FullAccess = "BUILTIN\Administrators"
            Ensure = "Present"
            DependsOn = "[File]FSWFolder"
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