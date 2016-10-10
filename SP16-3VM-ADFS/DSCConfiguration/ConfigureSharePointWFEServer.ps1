Configuration ConfigureSharePointWFEServer
{
    param (
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $DomainAdminCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPSetupCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPFarmCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPServicesCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPWebCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPContentCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPPassPhrase,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSuperReaderUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSuperUserUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPPrefix,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPWebAppUrl,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPMySiteUrl,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DatabaseServer,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $NumWeb,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $NumApp,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $NumSI,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $NumSC,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $NumDCache
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xDisk
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName SharePointDsc

    node "localhost"
    {
        $firstAppServer = $SPPrefix + "APP1"

        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainAdminCredential
        }

        xDisk LogsDisk { DiskNumber = 2; DriveLetter = "F"; DependsOn = "[xComputer]DomainJoin" }

        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xComputer]DomainJoin" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $CredSSPDelegates; DependsOn = "[xComputer]DomainJoin" }

        Group AddInstallAccountToAdminGroup
        {
            GroupName='Administrators'   
            Ensure= 'Present'             
            MembersToInclude= $SPSetupCredential.UserName
            Credential = $DomainAdminCredential    
            PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[xComputer]DomainJoin"
        }

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[xComputer]DomainJoin"}

        
        #Wait for farm to exist before we join
        WaitForAll WaitSPFarm
        {
            ResourceName = "[SPCreateFarm]CreateSPFarm"
            NodeName = $firstAppServer
            RetryIntervalSec = 60
            RetryCount = 60
            PsDscRunAsCredential = $SPSetupCredential
            DependsOn = "[Group]AddInstallAccountToAdminGroup"
        }

        SPJoinFarm JoinSPFarm
        {
            FarmConfigDatabaseName = $SPPrefix + "_Config"
            DatabaseServer = $DatabaseServer
            Passphrase = $SPPassPhrase
            ServerRole = 'WebFrontEnd'
            PsDscRunAsCredential = $SPSetupCredential
            DependsOn = "[WaitForAll]WaitSPFarm"
        }

        File WriteCompleteFile
        {
            DestinationPath = "F:\Logs\DSCDone.txt"
            PsDscRunAsCredential = $SPSetupCredential
            Contents = "DSC Done"
            Type = 'File'
            Force = $true
            DependsOn = "[SPJoinFarm]JoinSPFarm"
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