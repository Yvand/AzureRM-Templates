configuration ConfigureSPVM
{
    param
    (
        [Parameter(Mandatory)] [String]$DNSServer,
        [Parameter(Mandatory)] [String]$DomainFQDN,
        [Parameter(Mandatory)] [String]$DCName,
        [Parameter(Mandatory)] [String]$SQLName,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$DomainAdminCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSetupCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPFarmCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSvcCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPAppPoolCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPPassphraseCreds,
        [Parameter(Mandatory)] [bool]$IsCAServer
    )

    Import-DscResource -ModuleName xComputerManagement, xDisk, cDisk, xNetworking, xActiveDirectory, xCredSSP, xWebAdministration, SharePointDsc, xPSDesiredStateConfiguration, xDnsServer, xCertificate

    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter| Where-Object Name -Like "Ethernet*"| Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [System.Management.Automation.PSCredential] $SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential] $SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPFarmCreds.UserName)", $SPFarmCreds.Password)
    [System.Management.Automation.PSCredential] $SPSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSvcCreds.UserName)", $SPSvcCreds.Password)
    [System.Management.Automation.PSCredential] $SPAppPoolCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPAppPoolCreds.UserName)", $SPAppPoolCreds.Password)
    [String] $SPDBPrefix = "SPDSC_"
    [String] $SPTrustedSitesName = "SPSites"
    [Int] $RetryCount = 30
    [Int] $RetryIntervalSec = 30
    [String] $ComputerName = Get-Content env:computername
    [String] $LdapcpLink = (Get-LatestGitHubRelease -Repo "Yvand/LDAPCP" -Artifact "LDAPCP.wsp")
    [String] $PresentIfIsCaServer = (Get-PresentIfIsCaServer -IsCAServer $IsCAServer)
    [String] $ServiceAppPoolName = "SharePoint Service Applications"
    [String] $UpaServiceName = "User Profile Service Application"
    [String] $AppDomainFQDN = (Get-AppDomain -DomainFQDN $DomainFQDN -Suffix "Apps")
    [String] $AppDomainIntranetFQDN = (Get-AppDomain -DomainFQDN $DomainFQDN -Suffix "Apps-Intranet")

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
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }
        cDiskNoRestart SPDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
            DependsOn = "[xWaitforDisk]Disk2"
        }
        WindowsFeature ADPS     { Name = "RSAT-AD-PowerShell"; Ensure = "Present"; DependsOn = "[cDiskNoRestart]SPDataDisk" }
        WindowsFeature DnsTools { Name = "RSAT-DNS-Server";    Ensure = "Present"; DependsOn = "[cDiskNoRestart]SPDataDisk"  }
        xDnsServerAddress DnsServerAddress
        {
            Address        = $DNSServer
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn="[WindowsFeature]ADPS"
        }

        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xDnsServerAddress]DnsServerAddress" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = "*.$DomainFQDN", "localhost"; DependsOn = "[xCredSSP]CredSSPServer" }

        #**********************************************************
        # Join AD forest
        #**********************************************************
        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainFQDN
            DomainUserCredential= $DomainAdminCredsQualified
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn="[xCredSSP]CredSSPClient"
        }

        xComputer DomainJoin
        {
            Name = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        <#
        xScript RestartWSManService
        {
            SetScript = 
            {
                # 1 deployment failed because of this error:
                # "The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer because the computer is not trusted."
                # The root cause was that SPNs WSMAN/SP and WSMAN/sp.contoso.local were missing in computer account contoso\SP
                # Those SPNs are created by WSMan when it (re)starts
                Restart-Service winrm
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                return @{ "Result" = "false" }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
               return $false
            }
            DependsOn="[xComputer]DomainJoin"
        }
        #>

        #**********************************************************
        # Do some cleanup and preparation for SharePoint
        #**********************************************************
        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
            DependsOn="[xComputer]DomainJoin"
        }
        
        xDnsRecord AddTrustedSiteDNS 
        {
            Name = $SPTrustedSitesName
            Zone = $DomainFQDN
            DnsServer = $DCName
            Target = "$ComputerName.$DomainFQDN"
            Type = "CName"
            Ensure = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[xComputer]DomainJoin"
        }

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[xComputer]DomainJoin"}

        #**********************************************************
        # Provision required accounts for SharePoint
        #**********************************************************
        xADUser CreateSPSetupAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPSetupCreds.UserName
            Password = $SPSetupCreds
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        Group AddSPSetupAccountToAdminGroup
        {
            GroupName='Administrators'   
            Ensure= 'Present'             
            MembersToInclude= $SPSetupCredsQualified.UserName
            Credential = $DomainAdminCredsQualified    
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[xADUser]CreateSPSetupAccount"
        }

        xADUser CreateSParmAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPFarmCreds.UserName
            Password = $SPFarmCreds
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSPSvcAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPSvcCreds.UserName
            Password = $SPSvcCreds
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSPAppPoolAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPAppPoolCreds.UserName
            Password = $SPAppPoolCreds
            PasswordNeverExpires = $true
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        File AccountsProvisioned
        {
            DestinationPath = "F:\Logs\DSC1.txt"
            PsDscRunAsCredential = $SPSetupCredential
            Contents = "AccountsProvisioned"
            Type = 'File'
            Force = $true
            DependsOn = "[Group]AddSPSetupAccountToAdminGroup", "[xADUser]CreateSParmAccount", "[xADUser]CreateSPSvcAccount", "[xADUser]CreateSPAppPoolAccount"
        }

        
        #**********************************************************
        # Download binaries and install SharePoint CU
        #**********************************************************
        File CopyCertificatesFromDC
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$DCName\C$\Setup"
            DestinationPath = "F:\Setup\Certificates"
            Credential = $DomainAdminCredsQualified
            DependsOn = "[File]AccountsProvisioned"
        }

        xRemoteFile DownloadLdapcp
        {  
            Uri             = $LdapcpLink
            DestinationPath = "F:\Setup\LDAPCP.wsp"
            DependsOn = "[File]AccountsProvisioned"
        }        

        <#
        xRemoteFile Download201612CU
        {  
            Uri             = "https://download.microsoft.com/download/D/0/4/D04FD356-E140-433E-94F6-472CF45FD591/sts2016-kb3128014-fullfile-x64-glb.exe"
            DestinationPath = "F:\Setup\sts2016-kb3128014-fullfile-x64-glb.exe"
            MatchSource = $false
            DependsOn = "[File]AccountsProvisioned"
        }

        xScript Install201612CU
        {
            SetScript = 
            {
                $cuBuildNUmber = "16.0.4471.1000"
                $updateLocation = "F:\setup\sts2016-kb3128014-fullfile-x64-glb.exe"
                $cuInstallLogPath = "F:\setup\sts2016-kb3128014-fullfile-x64-glb.exe.install.log"
                $setup = Start-Process -FilePath $updateLocation -ArgumentList "/log:`"$CuInstallLogPath`" /quiet /passive /norestart" -Wait -PassThru
 
                if ($setup.ExitCode -eq 0) {
                    Write-Verbose -Message "SharePoint cumulative update $cuBuildNUmber installation complete"
                }
                else
                {
                    Write-Verbose -Message "SharePoint cumulative update install failed, exit code was $($setup.ExitCode)"
                    throw "SharePoint cumulative update install failed, exit code was $($setup.ExitCode)"
                }
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                $cuBuildNUmber = "16.0.4471.1000"
                $result = "false"
                Write-Verbose -Message 'Getting Sharepoint buildnumber'

                try
                {
                    $spInstall = Get-SPDSCInstalledProductVersion
                    $build = $spInstall.ProductVersion
                    if ($build -eq $cuBuildNUmber) {
                        $result = "true"
                    }
                }
                catch
                {
                    Write-Verbose -Message 'Sharepoint not installed, CU installation is going to fail if attempted'
                }

                return @{ "Result" = $result }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
                $cuBuildNUmber = "16.0.4471.1000"
                $result = $false
                try
                {
                    Write-Verbose -Message "Getting Sharepoint build number"
                    $spInstall = Get-SPDSCInstalledProductVersion
                    $build = $spInstall.ProductVersion
                    Write-Verbose -Message "Current Sharepoint build number is $build and expected build number is $cuBuildNUmber"
                    if ($build -eq $cuBuildNUmber) {
                        $result = $true
                    }
                }
                catch
                {
                    Write-Verbose -Message "Sharepoint is not installed, abort installation of CU or it will fail otherwise"
                    $result = $true
                }
                return $result
            }
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[xRemoteFile]Download201612CU"
        }

        xPendingReboot RebootAfterInstall201612CU
        { 
            Name = 'RebootAfterInstall201612CU'
            DependsOn = "[xScript]Install201612CU"
        }

        xPackage Install201612CU
        {
            Ensure = "Present"
            Name = "Update for Microsoft SharePoint Enterprise Server 2016 (KB3128014) 64-Bit Edition"
            ProductId = "{ECE043F3-EEF8-4070-AF9B-D805C42A8ED4}"
            InstalledCheckRegHive = "LocalMachine"
            InstalledCheckRegKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{90160000-1014-0000-1000-0000000FF1CE}_Office16.OSERVER_{ECE043F3-EEF8-4070-AF9B-D805C42A8ED4}"
            InstalledCheckRegValueName = "DisplayName"
            InstalledCheckRegValueData = "Update for Microsoft SharePoint Enterprise Server 2016 (KB3128014) 64-Bit Edition"
            Path = "F:\setup\sts2016-kb3128014-fullfile-x64-glb.exe"
            Arguments = "/q"
            RunAsCredential = $DomainAdminCredsQualified
            ReturnCode = @( 0, 1641, 3010, 17025 )
            DependsOn = "[xPendingReboot]RebootAfterInstall201612CU"
        }

        # TODO: implement stupid workaround documented in https://technet.microsoft.com/en-us/library/mt723354(v=office.16).aspx until SP2016 image is fixed
        #>

        xScript WaitForSQL
        {
            SetScript = 
            {
                $retryCount = $using:RetryIntervalSec
                $server = $using:SQLName
                $db="master"
                $retry = $true
                while ($retry) {
                    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection "Data Source=$server;Initial Catalog=$db;Integrated Security=True;Enlist=False;Connect Timeout=3"
                    try {
                        $sqlConnection.Open()
                        Write-Verbose "Connection to SQL Server $server succeeded"
                        $sqlConnection.Close()
                        $retry = $false
                    }
                    catch {
                        Write-Verbose "SQL connection to $server failed, retry in $retryCount secs..."
                        Start-Sleep -s $retryCount
                    }
                }
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                return @{ "Result" = "false" }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
               return $false
            }
            PsDscRunAsCredential     = $DomainAdminCredsQualified
            DependsOn = "[xRemoteFile]DownloadLdapcp"
        }

        #**********************************************************
        # Basic SharePoint configuration
        #**********************************************************
        SPFarm CreateSPFarm
        {
            DatabaseServer            = $SQLName
            FarmConfigDatabaseName    = $SPDBPrefix + "Config"
            Passphrase                = $SPPassphraseCreds
            FarmAccount               = $SPFarmCredsQualified
            PsDscRunAsCredential      = $SPSetupCredsQualified
            AdminContentDatabaseName  = $SPDBPrefix + "AdminContent"
            CentralAdministrationPort = 5000
            # If RunCentralAdmin is false and configdb does not exist, SPFarm checks during 30 mins if configdb got created and joins the farm
            RunCentralAdmin           = $IsCAServer
            Ensure                    = "Present"
            DependsOn                 = "[xScript]WaitForSQL"
        }

        SPManagedAccount CreateSPSvcManagedAccount
        {
            AccountName          = $SPSvcCredsQualified.UserName
            Account              = $SPSvcCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPManagedAccount CreateSPAppPoolManagedAccount
        {
            AccountName          = $SPAppPoolCredsQualified.UserName
            Account              = $SPAppPoolCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            LogPath              = "F:\ULS"
            LogSpaceInGB         = 20
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = $SPDBPrefix + "StateService"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            CacheSizeInMB        = 8192
            CreateFirewallRules  = $true
            ServiceAccount       = $SPSvcCredsQualified.UserName
            InstallAccount       = $SPSetupCredsQualified
            Ensure               = "Present"
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        xScript RestartSPTimer
        {
            SetScript = 
            {
                # The deployment of the solution is made in owstimer.exe tends to fail very often, so restart the service before to mitigate this risk
                Restart-Service SPTimerV4
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                return @{ "Result" = "false" }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
               return $false
            }
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[SPDistributedCacheService]EnableDistributedCache"
        }

        SPFarmSolution InstallLdapcp 
        {
            LiteralPath = "F:\Setup\LDAPCP.wsp"
            Name = "LDAPCP.wsp"
            Deployed = $true
            Ensure = "Present"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[xScript]RestartSPTimer"
        }

        SPTrustedIdentityTokenIssuer CreateSPTrust
        {
            Name                         = $DomainFQDN
            Description                  = "Federation with $DomainFQDN"
            Realm                        = "https://$SPTrustedSitesName.$DomainFQDN"
            SignInUrl                    = "https://adfs.$DomainFQDN/adfs/ls/"
            IdentifierClaim              = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
            ClaimsMappings               = @(
                MSFT_SPClaimTypeMapping{
                    Name = "Email"
                    IncomingClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
                }
                MSFT_SPClaimTypeMapping{
                    Name = "Role"
                    IncomingClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
                }
            )
            SigningCertificateFilePath = "F:\Setup\Certificates\ADFS Signing.cer"
            ClaimProviderName            = "LDAPCP"
            #ProviderSignOutUri           = "https://adfs.$DomainFQDN/adfs/ls/"
            Ensure                       = "Present"
            DependsOn = "[SPFarmSolution]InstallLdapcp"
            PsDscRunAsCredential         = $SPSetupCredsQualified
        }
        
        SPWebApplication MainWebApp
        {
            Name                   = "SharePoint - 80"
            ApplicationPool        = "SharePoint - 80"
            ApplicationPoolAccount = $SPAppPoolCredsQualified.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = $SPDBPrefix + "Content_80"
            Url                    = "http://$SPTrustedSitesName/"
            Port                   = 80
            Ensure                 = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn              = "[SPTrustedIdentityTokenIssuer]CreateSPTrust"
        }

        <#xScript ExtendWebApp
        {
            SetScript = 
            {
                $ComputerName = $using:ComputerName
                $SPTrustedSitesName = $using:SPTrustedSitesName
                $DomainFQDN = $using:DomainFQDN

                $result = Invoke-SPDSCCommand -Credential $using:SPSetupCredsQualified -ScriptBlock {
                    Get-SPWebApplication "http://$ComputerName/" | New-SPWebApplicationExtension -Name "SharePoint - 443" -SecureSocketsLayer -Zone "Intranet" -URL "https://$SPTrustedSitesName.$DomainFQDN" -Port 443
                    $winAp = New-SPAuthenticationProvider -UseWindowsIntegratedAuthentication
                    $trust = Get-SPTrustedIdentityTokenIssuer $DomainFQDN
                    Get-SPWebApplication "http://$ComputerName/" | Set-SPWebApplication -Zone Intranet -AuthenticationProvider $trust, $winAp 
                                     
                    return "success"
                }
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                $result = "false"
                return @{ "Result" = $result }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
                return $false
            }
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = '[SPWebApplication]MainWebApp'
        }#>

        xCertReq SPSSiteCert
        {
            CARootName                = "$DomainNetbiosName-$DCName-CA"
            CAServerFQDN              = "$DCName.$DomainFQDN"
            Subject                   = "$SPTrustedSitesName.$DomainFQDN"
            SubjectAltName            = "dns=$SPTrustedSitesName.$DomainFQDN"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainAdminCredsQualified
            DependsOn = '[SPWebApplication]MainWebApp'
        }

        SPWebApplicationExtension ExtendWebApp
        {
            WebAppUrl              = "http://$SPTrustedSitesName/"
            Name                   = "SharePoint - 443"
            AllowAnonymous         = $false
            AuthenticationMethod   = "Claims"
            AuthenticationProvider = $DomainFQDN
            Url                    = "https://$SPTrustedSitesName.$DomainFQDN"
            Zone                   = "Intranet"
            UseSSL                 = $true
            Port                   = 443
            Ensure                 = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn = '[xCertReq]SPSSiteCert'
        }
        
        xScript SetHTTPSCertificate
        {
            SetScript = 
            {
                $siteCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "$using:SPTrustedSitesName.$using:DomainFQDN"

                $website = Get-WebConfiguration -Filter '/system.applicationHost/sites/site' |
                    Where-Object -FilterScript {$_.Name -eq "SharePoint - 443"}

                $properties = @{
                    protocol = "https"
                    bindingInformation = ":443:"
                    certificateStoreName = "MY"
                    certificateHash = $siteCert.Thumbprint
                }

                Clear-WebConfiguration -Filter "$($website.ItemXPath)/bindings" -Force -ErrorAction Stop
                Add-WebConfiguration -Filter "$($website.ItemXPath)/bindings" -Value @{
                    protocol = $properties.protocol
                    bindingInformation = $properties.bindingInformation
                    certificateStoreName = $properties.certificateStoreName
                    certificateHash = $properties.certificateHash
                } -Force -ErrorAction Stop

                if (!(Get-Item IIS:\SslBindings\*!443)) {
                    New-Item IIS:\SslBindings\*!443 -value $siteCert
                }
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                return @{ "Result" = "false" }
            }
            TestScript = 
            {
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
               return $false
            }
            PsDscRunAsCredential     = $DomainAdminCredsQualified
            DependsOn                = "[SPWebApplicationExtension]ExtendWebApp"
        }

        SPSite RootTeamSite
        {
            Url                      = "http://$SPTrustedSitesName/"
            OwnerAlias               = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias      = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                     = "Team site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[xScript]SetHTTPSCertificate"
        }

        SPSite DevSite
        {
            Url                      = "http://$SPTrustedSitesName/sites/dev"
            OwnerAlias               = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias      = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                     = "Developer site"
            Template                 = "DEV#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[xScript]SetHTTPSCertificate"
        }

        SPSite TeamSite
        {
            Url                      = "http://$SPTrustedSitesName/sites/team"
            OwnerAlias               = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias      = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                     = "Team site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[xScript]SetHTTPSCertificate"
        }

        SPSite MySiteHost
        {
            Url                      = "http://$SPTrustedSitesName/sites/my"
            OwnerAlias               = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias      = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                     = "MySite host"
            Template                 = "SPSMSITEHOST#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[xScript]SetHTTPSCertificate"
        }

        xScript CreateDefaultGroupsInTeamSites
        {
            GetScript = { return @{} }
            SetScript = {
                $argumentList = @(@{ "sitesToUpdate" = @("http://$using:SPTrustedSitesName", "http://$using:SPTrustedSitesName/sites/team"); 
                                     "owner1"        = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"; 
                                     "owner2"        = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN" })
                Invoke-SPDscCommand -Credential $DomainAdminCredsQualified -Arguments @argumentList -ScriptBlock {
                    # Create members/visitors/owners groups in team sites
                    $params = $args[0]
                    #$sitesToUpdate = Get-SPSite
                    $sitesToUpdate = $params.sitesToUpdate
                    $owner1 = $params.owner1
                    $owner2 = $params.owner2
                    
                    foreach ($spsite in $sitesToUpdate) {
                        if ($spsite.RootWeb.WebTemplate -like "STS") {
                            $teamsite.RootWeb.CreateDefaultAssociatedGroups($owner1, $owner2, $teamsite.Title);
                            $teamsite.RootWeb.Update();
                        }
                    }
                }
            }
            TestScript = { return $false }
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn = "[SPSite]RootTeamSite", "[SPSite]TeamSite"
        }

        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $ServiceAppPoolName
            ServiceAccount       = $SPSvcCredsQualified.UserName
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance UPAServiceInstance
        {  
            Name                 = "User Profile Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPUserProfileServiceApp UserProfileServiceApp
        {
            Name                 = $UpaServiceName
            ApplicationPool      = $ServiceAppPoolName
            MySiteHostLocation   = "http://$SPTrustedSitesName/sites/my"
            ProfileDBName        = $SPDBPrefix + "UPA_Profiles"
            SocialDBName         = $SPDBPrefix + "UPA_Social"
            SyncDBName           = $SPDBPrefix + "UPA_Sync"
            EnableNetBIOS        = $false
            FarmAccount          = $SPFarmCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[SPServiceAppPool]MainServiceAppPool", "[SPSite]MySiteHost"
        }
        
        # Added that to avoid the update conflict error (UpdatedConcurrencyException) of the UserProfileApplication persisted object
        # Error message avoided: UpdatedConcurrencyException: The object UserProfileApplication Name=User Profile Service Application was updated by another user.  Determine if these changes will conflict, resolve any differences, and reapply the second change.  This error may also indicate a programming error caused by obtaining two copies of the same object in a single thread. Previous update information: User: CONTOSO\spfarm Process:wsmprovhost (8632) Machine:SP Time:October 17, 2017 11:25:01.0000 Stack trace (Thread [16] CorrelationId [2c50ced7-4721-0003-b7f3-502c2147d301]):  Current update information: User: CONTOSO\spsetup Process:wsmprovhost (696) Machine:SP Time:October 17, 2017 11:25:06.0252 Stack trace (Thread [62] CorrelationId [37bd239e-a854-f0e6-ee90-b0567bfec821]):  
        xScript RefreshLocalConfigCache
        {
            SetScript = 
            {
                $methodName = "get_Local"
                $assembly = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
                $SPConfigurationDBType = $assembly.GetType("Microsoft.SharePoint.Administration.SPConfigurationDatabase")

                $bindingFlags = [Reflection.BindingFlags] "Public, Static"
                $localProp = [System.Reflection.MethodInfo] $SPConfigurationDBType.GetMethod($methodName, $bindingFlags)
                $SPConfigurationDBObject = $localProp.Invoke($null, $null)

                $methodName = "FlushCache"  # method RefreshCache() does not fix the UpdatedConcurrencyException, so use FlushCache instead
                $bindingFlags = [Reflection.BindingFlags] "NonPublic, Instance"
                $localProp = [System.Reflection.MethodInfo] $SPConfigurationDBType.GetMethod($methodName, $bindingFlags)
                $localProp.Invoke($SPConfigurationDBObject, $null)
            }
            GetScript = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[SPUserProfileServiceApp]UserProfileServiceApp"
        }

        # Grant spsvc full control to UPA to allow newsfeeds to work properly
        $upaAdminToInclude = @( 
            MSFT_SPServiceAppSecurityEntry {
                Username    = $SPSvcCredsQualified.UserName
                AccessLevel = "Full Control"
        })
        SPServiceAppSecurity UserProfileServiceSecurity
        {
            ServiceAppName       = $UpaServiceName
            SecurityType         = "SharingPermissions"
            MembersToInclude     = $upaAdminToInclude
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[xScript]RefreshLocalConfigCache"
        }

        #**********************************************************
        # Addins configuration
        #**********************************************************
        xDnsRecord AddAddinDNSWildcard {
            Name = "*"
            Zone = $AppDomainFQDN
            Target = "$ComputerName.$DomainFQDN"
            Type = "CName"
            DnsServer = "$DCName.$DomainFQDN"
            Ensure = "Present"
            PsDscRunAsCredential = $DomainAdminCreds
            DependsOn = "[SPServiceAppSecurity]UserProfileServiceSecurity"
        }

        xDnsRecord AddAddinDNSWildcardInIntranetZone {
            Name = "*"
            Zone = $AppDomainIntranetFQDN
            Target = "$ComputerName.$DomainFQDN"
            Type = "CName"
            DnsServer = "$DCName.$DomainFQDN"
            Ensure = "Present"
            PsDscRunAsCredential = $DomainAdminCreds
            DependsOn = "[xDnsRecord]AddAddinDNSWildcard"
        }

        SPServiceInstance StartSubscriptionSettingsServiceInstance
        {  
            Name                 = "Microsoft SharePoint Foundation Subscription Settings Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[xDnsRecord]AddAddinDNSWildcardInIntranetZone"
        }

        SPSubscriptionSettingsServiceApp CreateSubscriptionSettingsServiceApp
        {
            Name                 = "Subscription Settings Service Application"
            ApplicationPool      = $ServiceAppPoolName
            DatabaseName         = "$($SPDBPrefix)SubscriptionSettings"
            PsDscRunAsCredential = $SPSetupCredsQualified  
            DependsOn = "[SPServiceInstance]StartSubscriptionSettingsServiceInstance"
        }

        SPServiceInstance StartAppManagementServiceInstance
        {  
            Name                 = "App Management Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[SPSubscriptionSettingsServiceApp]CreateSubscriptionSettingsServiceApp"
        }

        SPAppManagementServiceApp CreateAppManagementServiceApp
        {
            Name                 = "App Management Service Application"
            ApplicationPool      = $ServiceAppPoolName
            DatabaseName         = "$($SPDBPrefix)AppManagement"
            PsDscRunAsCredential = $SPSetupCredsQualified  
            DependsOn = "[SPServiceInstance]StartSubscriptionSettingsServiceInstance"
        }

        SPAppDomain ConfigureLocalFarmAppUrls
        {
            AppDomain            = $AppDomainFQDN
            Prefix               = "addin"
            PsDscRunAsCredential = $SPSetupCredsQualified  
            DependsOn = "[SPServiceInstance]StartSubscriptionSettingsServiceInstance"
        }

        SPSite AppCatalog
        {
            Url                      = "http://$SPTrustedSitesName/sites/AppCatalog"
            OwnerAlias               = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias      = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                     = "AppCatalog"
            Template                 = "APPCATALOG#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[SPAppDomain]ConfigureLocalFarmAppUrls"
        }

        Script ConfigureSTSAndMultipleZones
        {
            GetScript = { return @{} }
            SetScript = {
                $argumentList = @(@{ "webAppUrl"             = "http://$using:SPTrustedSitesName"; 
                                     "AppDomainFQDN"         = "$using:AppDomainFQDN"; 
                                     "AppDomainIntranetFQDN" = "$using:AppDomainIntranetFQDN" })
                Invoke-SPDscCommand -Credential $DomainAdminCredsQualified -Arguments @argumentList -ScriptBlock {
                    $params = $args[0]
                    
                    # Configure STS
                    $serviceConfig = Get-SPSecurityTokenServiceConfig
                    $serviceConfig.AllowOAuthOverHttp = $true
                    $serviceConfig.Update()

                    # Configure app domains in zones of the web application
                    $webAppUrl = $params.webAppUrl
                    $appDomainDefaultZone = $params.AppDomainFQDN
                    $appDomainIntranetZone = $params.AppDomainIntranetFQDN

                    $defaultZoneConfig = Get-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Default
                    if($defaultZoneConfig -eq $null) {
                        New-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Default -AppDomain $appDomainDefaultZone -ErrorAction SilentlyContinue
                    }
                    elseif ($defaultZoneConfig.AppDomain -notlike $appDomainDefaultZone) {
                        $defaultZoneConfig| Remove-SPWebApplicationAppDomain -Confirm:$false
                        New-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Default -AppDomain $appDomainDefaultZone -ErrorAction SilentlyContinue
                    }

                    $IntranetZoneConfig = Get-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Intranet
                    if($IntranetZoneConfig -eq $null) {
                        New-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Intranet -SecureSocketsLayer -AppDomain $appDomainIntranetZone -ErrorAction SilentlyContinue
                    }
                    elseif ($IntranetZoneConfig.AppDomain -notlike $appDomainIntranetZone) {
                        $IntranetZoneConfig| Remove-SPWebApplicationAppDomain -Confirm:$false
                        New-SPWebApplicationAppDomain -WebApplication $webAppUrl -Zone Intranet -SecureSocketsLayer -AppDomain $appDomainIntranetZone -ErrorAction SilentlyContinue
                    }

                    # Configure app catalog
                    # Deactivated because it throws "Access is denied. (Exception from HRESULT: 0x80070005 (E_ACCESSDENIED))"
                    #Update-SPAppCatalogConfiguration -Site "$webAppUrl/sites/AppCatalog" -Confirm:$false
                }
            }
            TestScript = { return $false }
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn = "[SPSite]AppCatalog"
        }

        # Deactivated because it throws "Access is denied. (Exception from HRESULT: 0x80070005 (E_ACCESSDENIED))"
        <#SPAppCatalog MainAppCatalog
        {
            SiteUrl              = "http://$SPTrustedSitesName/sites/AppCatalog"
            InstallAccount       = $SPSetupCredsQualified
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPSite]AppCatalog"
        }#>
    }
}

function Get-LatestGitHubRelease
{
    [OutputType([string])]
    param(
        [string] $Repo,
        [string] $Artifact
    )
    # Found in https://blog.markvincze.com/download-artifacts-from-a-latest-github-release-in-sh-and-powershell/
    $latestRelease = Invoke-WebRequest https://github.com/$Repo/releases/latest -Headers @{"Accept"="application/json"} -UseBasicParsing
    $json = $latestRelease.Content | ConvertFrom-Json
    $latestVersion = $json.tag_name
    $url = "https://github.com/$Repo/releases/download/$latestVersion/$Artifact"
    return $url
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

function Get-AppDomain
{
    [OutputType([string])]
    param(
        [string]$DomainFQDN,
        [string]$Suffix
    )

    $appDomain = [String]::Empty
    if ($DomainFQDN.Contains('.')) {
        $domainParts = $DomainFQDN.Split('.')
        $appDomain = $domainParts[0]
        $appDomain += "$Suffix."
        $appDomain += $domainParts[1]
    }
    return $appDomain
}

function Get-SPDSCInstalledProductVersion
{
    $pathToSearch = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\*\ISAPI\Microsoft.SharePoint.dll"
    $fullPath = Get-Item $pathToSearch | Sort-Object { $_.Directory } -Descending | Select-Object -First 1
    return (Get-Command $fullPath).FileVersionInfo
}

function Get-PresentIfIsCaServer
{
    [OutputType([string])]
    param(
        [bool]$IsCAServer
    )
    if ($IsCAServer -eq $true) { return "Present" } else { return "Absent" }
}

<#
# Azure DSC extension logging: C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.21.0.0
# Azure DSC extension configuration: C:\Packages\Plugins\Microsoft.Powershell.DSC\2.21.0.0\DSCWork

Install-Module -Name xPendingReboot
help ConfigureSPVM

$DomainAdminCreds = Get-Credential -Credential "yvand"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$SPFarmCreds = Get-Credential -Credential "spfarm"
$SPSvcCreds = Get-Credential -Credential "spsvc"
$SPAppPoolCreds = Get-Credential -Credential "spapppool"
$SPPassphraseCreds = Get-Credential -Credential "Passphrase"
$DNSServer = "10.0.1.4"
$DomainFQDN = "contoso.local"
$DCName = "DC"
$SQLName = "SQL"
$IsCAServer = $false

ConfigureSPVM -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPSvcCreds $SPSvcCreds -SPAppPoolCreds $SPAppPoolCreds -SPPassphraseCreds $SPPassphraseCreds -DNSServer $DNSServer -DomainFQDN $DomainFQDN -DCName $DCName -SQLName $SQLName -IsCAServer $IsCAServer -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.71.1.0\DSCWork\ConfigureSPVM.0\ConfigureSPVM"
Set-DscLocalConfigurationManager -Path "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.71.1.0\DSCWork\ConfigureSPVM.0\ConfigureSPVM"
Start-DscConfiguration -Path "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.71.1.0\DSCWork\ConfigureSPVM.0\ConfigureSPVM" -Wait -Verbose -Force

#>
