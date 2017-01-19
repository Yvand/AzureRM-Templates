configuration ConfigureSPVM
{
    param
    (
		[Parameter(Mandatory)]
        [String]$DNSServer,

        [Parameter(Mandatory)]
        [String]$DomainFQDN,
        [String]$DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN),

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$DomainAdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupCreds,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPFarmCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSvcCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPAppPoolCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPPassphraseCreds
    )

    Import-DscResource -ModuleName xComputerManagement, xDisk, cDisk, xNetworking, xActiveDirectory, xCredSSP, xWebAdministration, SharePointDsc, xPSDesiredStateConfiguration, xPendingReboot

    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)
    [System.Management.Automation.PSCredential]$DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential]$SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential]$SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPFarmCreds.UserName)", $SPFarmCreds.Password)
    [System.Management.Automation.PSCredential]$SPSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSvcCreds.UserName)", $SPSvcCreds.Password)
    [System.Management.Automation.PSCredential]$SPAppPoolCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPAppPoolCreds.UserName)", $SPAppPoolCreds.Password)
    [String]$SPDBPrefix = "SP16DSC_"
	[Int]$RetryCount = 30
    [Int]$RetryIntervalSec = 30

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
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = "[cDiskNoRestart]SPDataDisk"
        }
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
            Name = $env:COMPUTERNAME
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        #**********************************************************
        # Do some cleanup and preparation for SharePoint
        #**********************************************************
        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
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
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSPSvcAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPSvcCreds.UserName
            Password = $SPSvcCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xADUser CreateSPAppPoolAccount
        {
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DomainName = $DomainFQDN
            UserName = $SPAppPoolCreds.UserName
            Password = $SPAppPoolCreds
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
        xRemoteFile DownloadLdapcp 
        {  
            Uri             = "https://ldapcp.codeplex.com/downloads/get/557616"
            DestinationPath = "F:\Setup\LDAPCP.wsp"
            DependsOn = "[File]AccountsProvisioned"
        }

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
        }

        <#
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
            DependsOn = "[xRemoteFile]Download201612CU"
        }

        # TODO: implement stupid workaround documented in https://technet.microsoft.com/en-us/library/mt723354(v=office.16).aspx until SP2016 image is fixed
        #>

        #**********************************************************
        # SharePoint configuration
        #**********************************************************
        SPCreateFarm CreateSPFarm
        {
            DatabaseServer           = "sql"
            FarmConfigDatabaseName   = $SPDBPrefix+"Config"
            Passphrase               = $SPPassphraseCreds
            FarmAccount              = $SPFarmCredsQualified
            PsDscRunAsCredential     = $SPSetupCredsQualified
            AdminContentDatabaseName = $SPDBPrefix+"AdminContent"
            CentralAdministrationPort = 5000
            #DependsOn = "[xPackage]Install201612CU"
            DependsOn = "[xRemoteFile]Download201612CU"
        }

        SPManagedAccount CreateSPSvcManagedAccount
        {
            AccountName          = $SPSvcCredsQualified.UserName
            Account              = $SPSvcCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPManagedAccount CreateSPAppPoolManagedAccount
        {
            AccountName          = $SPAppPoolCredsQualified.UserName
            Account              = $SPAppPoolCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            LogPath                                     = "F:\ULS"
            LogSpaceInGB = 20
            PsDscRunAsCredential                        = $SPSetupCredsQualified
            DependsOn                                   = "[SPCreateFarm]CreateSPFarm"
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            CacheSizeInMB        = 8192
            CreateFirewallRules  = $true
            ServiceAccount       = $SPSvcCredsQualified.UserName
            InstallAccount       = $SPSetupCredsQualified
            Ensure               = "Present"
        }

        SPFarmSolution InstallLdapcp 
        {
            LiteralPath = "F:\Setup\LDAPCP.wsp"
            Name = "LDAPCP.wsp"
            Deployed = $true
            Ensure = "Present"
            PsDscRunAsCredential  = $SPSetupCredsQualified
            DependsOn = "[SPDistributedCacheService]EnableDistributedCache"
        }

        SPWebApplication MainWebApp
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = "SharePoint Sites - 80"
            ApplicationPoolAccount = $SPAppPoolCredsQualified.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = $SPDBPrefix + "Content_80"
            Url                    = "http://sp"
            Port                   = 80
            Ensure = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn              = "[SPFarmSolution]InstallLdapcp"
        }

        SPSite TeamSite
        {
            Url                      = "http://sp"
            OwnerAlias               = $DomainAdminCredsQualified.UserName
            Name                     = "Team site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupCredsQualified
            DependsOn                = "[SPWebApplication]MainWebApp"
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

function Get-SPDSCInstalledProductVersion
{
    $pathToSearch = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\*\ISAPI\Microsoft.SharePoint.dll"
    $fullPath = Get-Item $pathToSearch | Sort-Object { $_.Directory } -Descending | Select-Object -First 1
    return (Get-Command $fullPath).FileVersionInfo
}


<#
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

ConfigureSPVM -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPSvcCreds $SPSvcCreds -SPAppPoolCreds $SPAppPoolCreds -SPPassphraseCreds $SPPassphraseCreds -DNSServer $DNSServer -DomainFQDN $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

#>
