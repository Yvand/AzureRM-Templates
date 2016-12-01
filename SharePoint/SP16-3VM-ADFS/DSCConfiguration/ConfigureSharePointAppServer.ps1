Configuration ConfigureSharePointAppServer
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
        #**********************************************************
        # Server configuration
        #
        # This section of the configuration includes details of the
        # server level configuration, such as disks, registry
        # settings, local admins, etc
        #********************************************************** 

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

        $servername = $env:COMPUTERNAME
        $firstAppServer = $SPPrefix + "APP1"
        $firstCrawlServer = $SPPrefix + "SC1"
        
        #**********************************************************
        # IIS clean up
        #
        # This section removes all default sites and application
        # pools from IIS as they are not required
        #**********************************************************

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[xComputer]DomainJoin"}

        if ($servername.ToLower() -eq $firstAppServer.ToLower())
        {
            File 1WriteDSCCompleteFile
            {
                DestinationPath = "F:\Logs\DSC1.txt"
                PsDscRunAsCredential = $SPSetupCredential
                Contents = "DSC First App"
                Type = 'File'
                Force = $true
                DependsOn = "[xWebSite]RemoveDefaultWebSite"
            }

            #**********************************************************
            # IIS clean up
            #
            # This section removes all default sites and application
            # pools from IIS as they are not required
            #**********************************************************
            SPCreateFarm CreateSPFarm
            {
                FarmConfigDatabaseName = $SPPrefix + "_Config"
                DatabaseServer =         $DatabaseServer
                FarmAccount = $SPFarmCredential
                Passphrase = $SPPassPhrase
                AdminContentDatabaseName = $SPPrefix + "_AdminContent"
                CentralAdministrationPort = 9999
                CentralAdministrationAuth = 'NTLM'
                ServerRole = 'Application'
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn = @("[xComputer]DomainJoin","[xWebSite]RemoveDefaultWebSite")
            }

            SPManagedAccount ServicePoolManagedAccount
            {
                AccountName          = $SPServicesCredential.UserName
                Account              = $SPServicesCredential
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = "[SPCreateFarm]CreateSPFarm"
            }

            SPManagedAccount WebPoolManagedAccount
            {
                AccountName          = $SPWebCredential.UserName
                Account              = $SPWebCredential
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = "[SPCreateFarm]CreateSPFarm"
            }

            SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
            {
                LogPath                                     = "F:\Logs"
                LogSpaceInGB                                = 10
                AppAnalyticsAutomaticUploadEnabled          = $false
                CustomerExperienceImprovementProgramEnabled = $true
                DaysToKeepLogs                              = 7
                DownloadErrorReportingUpdatesEnabled        = $false
                ErrorReportingAutomaticUploadEnabled        = $false
                ErrorReportingEnabled                       = $false
                EventLogFloodProtectionEnabled              = $true
                EventLogFloodProtectionNotifyInterval       = 5
                EventLogFloodProtectionQuietPeriod          = 2
                EventLogFloodProtectionThreshold            = 5
                EventLogFloodProtectionTriggerPeriod        = 2
                LogCutInterval                              = 15
                LogMaxDiskSpaceUsageEnabled                 = $true
                ScriptErrorReportingDelay                   = 30
                ScriptErrorReportingEnabled                 = $true
                ScriptErrorReportingRequireAuth             = $true
                PsDscRunAsCredential                        = $SPSetupCredential
                DependsOn                                   = "[SPCreateFarm]CreateSPFarm"
            }

            SPStateServiceApp StateServiceApp
            {
                Name                 = "State Service Application"
                DatabaseName         = $SPPrefix + "_State"
                DatabaseServer       = $DatabaseServer
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = "[SPCreateFarm]CreateSPFarm"
            }

            #Wait for all servers to be joined to the farm before we continue
            $waitTask = "[SPStateServiceApp]StateServiceApp"
            $servers = @()
            $searchindex = @()
            $searchcrawl = @()
        
            for ($i=1; $i -le $NumWeb; $i++) 
            {
                $servers += $SPPrefix + "WEB" + $i.ToString()
            }

            if ($NumApp -gt 1) {
                for ($i=2; $i -le $NumApp; $i++) {
                    $servers += $SPPrefix + "APP" + $i.ToString()
                }
            }

            #We will only wait for the first DCACHE server
            $servers += $SPPrefix + "DCACHE1"
            #for ($i=1; $i -le $NumDCache; $i++) 
            #{
            #    $servers += $SPPrefix + "DCACHE" + $i.ToString()
            #}

            for ($i=1; $i -le $NumSI; $i++) 
            {
                $servers += $SPPrefix + "SI" + $i.ToString()
                $searchindex += $SPPrefix + "SI" + $i.ToString()
            }

            for ($i=1; $i -le $NumSC; $i++) 
            {
                $servers += $SPPrefix + "SC" + $i.ToString()
                $searchcrawl += $SPPrefix + "SC" + $i.ToString()
            }

            if ($servers.Length -gt 0) {
                WaitForAll WaitForServers
                {
                    ResourceName = "[SPJoinFarm]JoinSPFarm"
                    NodeName = $servers
                    RetryIntervalSec = 60
                    RetryCount = 60
                    DependsOn = $waitTask
                }

                $waitTask = "[WaitForAll]WaitForServers"
            }


            $ServiceAppPoolName = "SharePoint Service Applications"
            SPServiceAppPool MainServiceAppPool
            {
                Name                 = $ServiceAppPoolName
                ServiceAccount       = $SPServicesCredential.UserName
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = $waitTask
            }

            SPSecureStoreServiceApp SecureStoreServiceApp
            {
                Name                  = "Secure Store Service Application"
                ApplicationPool       = $ServiceAppPoolName
                AuditingEnabled       = $true
                AuditlogMaxSize       = 30
                DatabaseName          = $SPPrefix + "_SecureStore"
                DatabaseServer        = $DatabaseServer
                PsDscRunAsCredential  = $SPSetupCredential
                DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
            }

            SPManagedMetaDataServiceApp ManagedMetadataServiceApp
            {  
                Name                 = "Managed Metadata Service Application"
                ApplicationPool      = $ServiceAppPoolName
                DatabaseName         = $SPPrefix + "_MMS"
                DatabaseServer       = $DatabaseServer
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
            }

            SPBCSServiceApp BCSServiceApp
            {
                Name                  = "BCS Service Application"
                ApplicationPool       = $ServiceAppPoolName
                DatabaseName          = $SPPrefix + "_BCS"
                DatabaseServer        = $DatabaseServer
                PsDscRunAsCredential  = $SPSetupCredential
                DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSecureStoreServiceApp]SecureStoreServiceApp')
            }

            SPAppManagementServiceApp AppManagementServiceApp
            {
                Name                  = "Application Management Service Application"
                DatabaseName          = $SPPrefix + "_AppManagement"
                DatabaseServer        = $DatabaseServer
                ApplicationPool       = $ServiceAppPoolName
                PsDscRunAsCredential  = $SPSetupCredential
                DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
            }

            SPSubscriptionSettingsServiceApp SubscriptionSettingsServiceApp
            {
                Name                  = "Subscription Settings Service Application"
                DatabaseName          = $SPPrefix + "_SubscriptionSettings"
                DatabaseServer        = $DatabaseServer
                ApplicationPool       = $ServiceAppPoolName
                PsDscRunAsCredential  = $SPSetupCredential
                DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
            }

            #**********************************************************
            # Web applications
            #
            # This section creates the web applications in the 
            # SharePoint farm, as well as managed paths and other web
            # application settings
            #**********************************************************
            $useSSL = $SPWebAppUrl.ToLower().Contains('https://')
            SPWebApplication HostWebApplication
            {
                Name                   = "SharePoint PLA Sites"
                ApplicationPool        = "SharePoint PLA Sites App Pool"
                ApplicationPoolAccount = $SPWebCredential.UserName
                AllowAnonymous         = $false
                UseSSL                 = $useSSL
                AuthenticationMethod   = 'NTLM'
                DatabaseName           = $SPPrefix + "_SitesContent"
                DatabaseServer         = $DatabaseServer
                Url                    = $SPWebAppUrl
                Port                   = [Uri]::new($SPWebAppUrl).Port
                PsDscRunAsCredential   = $SPSetupCredential
                DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
            }   
        
            #Web Application Settings
            SPWebAppGeneralSettings SiteGeneralSettings
            {
                Url = $SPWebAppUrl
                MaximumUploadSize = 250
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn = "[SPWebApplication]HostWebApplication"
            }

            #Root Site Collections
            SPSite HostSiteCollection
            {
                Url                      = $SPWebAppUrl
                OwnerAlias               = $SPSetupCredential.UserName
                Name                     = "Root site"
                Template                 = "STS#0"
                PsDscRunAsCredential     = $SPSetupCredential
                DependsOn                = "[SPWebApplication]HostWebApplication"
            }

            #Managed Paths
            SPManagedPath ManagedPathTeams
            {
                WebAppUrl            = $SPWebAppUrl
                PsDscRunAsCredential = $SPSetupCredential
                RelativeUrl          = "teams"
                Explicit             = $false
                HostHeader           = $false 
                DependsOn            = "[SPWebApplication]HostWebApplication"
            }

            SPManagedPath ManagedPathSites
            {
                WebAppUrl            = $SPWebAppUrl
                PsDscRunAsCredential = $SPSetupCredential
                RelativeUrl          = "sites"
                Explicit             = $false
                HostHeader           = $false 
                DependsOn            = "[SPWebApplication]HostWebApplication"
            }

            SPManagedPath ManagedPathPersonal
            {
                WebAppUrl            = $SPWebAppUrl
                PsDscRunAsCredential = $SPSetupCredential
                RelativeUrl          = "personal"
                Explicit             = $false
                HostHeader           = $false 
                DependsOn            = "[SPWebApplication]HostWebApplication"
            }

            SPManagedPath ManagedPathSearch
            {
                WebAppUrl            = $SPWebAppUrl
                PsDscRunAsCredential = $SPSetupCredential
                RelativeUrl          = "search"
                Explicit             = $true
                HostHeader           = $false 
                DependsOn            = "[SPWebApplication]HostWebApplication"
            }

            #Set the CachAccounts for the web application
            SPCacheAccounts AddCacheAccounts
            {
                WebAppUrl              = $SPWebAppUrl
                SuperUserAlias         = $SPSuperUserUsername
                SuperReaderAlias       = $SPSuperReaderUsername
                PsDscRunAsCredential   = $SPSetupCredential
                DependsOn              = "[SPWebApplication]HostWebApplication"
            }

            #Create My Site
            SPSite MySiteSiteCollection
            {
                Url                      = $SPMySiteUrl
                OwnerAlias               = $SPSetupCredential.UserName
                HostHeaderWebApplication = $SPWebAppUrl
                Name                     = "My Sites"
                Template                 = "SPSMSITEHOST#0"
                PsDscRunAsCredential     = $SPSetupCredential
                DependsOn              = "[SPManagedPath]ManagedPathPersonal"
            }

            #Create Search Center
            SPSite SearchCenterSiteCollection
            {
                Url                      = $SPWebAppUrl + "/search"
                OwnerAlias               = $SPSetupCredential.UserName
                Name                     = "Search"
                Template                 = "SRCHCEN#0"
                PsDscRunAsCredential     = $SPSetupCredential
                DependsOn              = "[SPManagedPath]ManagedPathSearch"
            }

            #Content Type Hub
            SPSite ContentTypeHubSiteCollection
            {
                Url                      = $SPWebAppUrl + "/sites/contenttypehub"
                OwnerAlias               = $SPSetupCredential.UserName
                Name                     = "Content Type Hub"
                Template                 = "STS#0"
                PsDscRunAsCredential     = $SPSetupCredential
                DependsOn              = "[SPManagedPath]ManagedPathSites"
            }

            SPUserProfileServiceApp UserProfileServiceApp
            {
                Name                 = "User Profile Service Application"
                ApplicationPool      = $ServiceAppPoolName
                MySiteHostLocation   = $SPMySiteUrl
                ProfileDBName        = $SPPrefix + "_ProfileDB"
                ProfileDBServer      = $DatabaseServer
                SocialDBName         = $SPPrefix + "_SocialDB"
                SocialDBServer       = $DatabaseServer
                SyncDBName           = $SPPrefix + "_SyncDB"
                SyncDBServer         = $DatabaseServer
                FarmAccount          = $SPFarmCredential
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn            = '[SPSite]MySiteSiteCollection'
            }

            SPSearchServiceApp SearchServiceApplication
            {
                Name = "Search Service Application"
                ApplicationPool = $ServiceAppPoolName
                DatabaseName = $SPPrefix + "_Search"
                DatabaseServer = $DatabaseServer
                DefaultContentAccessAccount = $SPContentCredential
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn = "[SPSite]SearchCenterSiteCollection"
            }

            #Search Topology
            SPSearchTopology SearchTopology
            {
                ServiceAppName = "Search Service Application"
                Admin = $firstCrawlServer
                Crawler = $searchcrawl
                ContentProcessing = $searchcrawl
                AnalyticsProcessing = $searchcrawl
                QueryProcessing = $searchindex
                IndexPartition = $searchindex
                FirstPartitionDirectory = "F:\searchindex\0"
                PsDscRunAsCredential = $SPSetupCredential
                DependsOn = "[SPSearchServiceApp]SearchServiceApplication"
            }
            
            File WriteDSCCompleteFile
            {
                DestinationPath = "F:\Logs\DSCDone.txt"
                PsDscRunAsCredential = $SPSetupCredential
                Contents = "DSC Done"
                Type = 'File'
                Force = $true
                DependsOn = "[SPUserProfileServiceApp]UserProfileServiceApp"
            }
        }
        else
        {
            File 2WriteDSCCompleteFile
            {
                DestinationPath = "F:\Logs\DSC2.txt"
                PsDscRunAsCredential = $SPSetupCredential
                Contents = "DSC Other App"
                Type = 'File'
                Force = $true
                DependsOn = "[xWebSite]RemoveDefaultWebSite"
            }

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
                ServerRole = 'Application'
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
            ActionAfterReboot = 'ContinueConfiguration'
        }
    }
}