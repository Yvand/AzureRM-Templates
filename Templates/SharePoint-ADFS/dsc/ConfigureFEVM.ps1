configuration ConfigureFEVM
{
    param
    (
        [Parameter(Mandatory)] [String]$DNSServer,
        [Parameter(Mandatory)] [String]$DomainFQDN,
        [Parameter(Mandatory)] [String]$DCName,
        [Parameter(Mandatory)] [String]$SQLName,
        [Parameter(Mandatory)] [String]$SQLAlias,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$DomainAdminCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSetupCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPFarmCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSvcCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPPassphraseCreds
    )

    Import-DscResource -ModuleName ComputerManagementDsc, NetworkingDsc, ActiveDirectoryDsc, xCredSSP, xWebAdministration, SharePointDsc, xPSDesiredStateConfiguration, xDnsServer, CertificateDsc, SqlServerDsc

    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter| Where-Object Name -Like "Ethernet*"| Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [System.Management.Automation.PSCredential] $SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential] $SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPFarmCreds.UserName)", $SPFarmCreds.Password)
    [System.Management.Automation.PSCredential] $SPSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSvcCreds.UserName)", $SPSvcCreds.Password)
    [String] $SPDBPrefix = "SPDSC_"
    [String] $SPTrustedSitesName = "SPSites"
    [String] $ComputerName = Get-Content env:computername
    [String] $AppDomainIntranetFQDN = (Get-AppDomain -DomainFQDN $DomainFQDN -Suffix "Apps-Intranet")
    [String] $MySiteHostAlias = "OhMy"
    [String] $HNSC1Alias = "HNSC1"

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Initialization of VM - Do as much work as possible before waiting on AD domain to be available
        #**********************************************************
        WindowsFeature ADTools  { Name = "RSAT-AD-Tools";      Ensure = "Present"; }
        WindowsFeature ADPS     { Name = "RSAT-AD-PowerShell"; Ensure = "Present"; }
        WindowsFeature DnsTools { Name = "RSAT-DNS-Server";    Ensure = "Present"; }
        DnsServerAddress SetDNS { Address = $DNSServer; InterfaceAlias = $InterfaceAlias; AddressFamily  = 'IPv4' }

        # xCredSSP is required forSharePointDsc resources SPUserProfileServiceApp and SPDistributedCacheService
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[DnsServerAddress]SetDNS" }
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = "*.$DomainFQDN", "localhost"; DependsOn = "[xCredSSP]CredSSPServer" }

        # IIS cleanup
        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; }
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; }
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; }
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; }
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; }
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; }
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; }

        # Allow sign-in on HTTPS sites when site host name is different than the machine name: https://support.microsoft.com/en-us/help/926642
        Registry DisableLoopBackCheck
        {
            Key       = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            DependsOn = "[PendingReboot]RebootOnComputerSignal"
        }

        # Properly enable TLS 1.2 as documented in https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/application-proxy-add-on-premises-application
        # It's a best practice, and mandatory with Windows 2012 R2 (SharePoint 2013) to allow xRemoteFile to download releases from GitHub: https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405           
        Registry EnableTLS12RegKey1
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'DisabledByDefault'
            ValueType = 'Dword'
            ValueData =  '0'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey2
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'Enabled'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey3
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'DisabledByDefault'
            ValueType = 'Dword'
            ValueData =  '0'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey4
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        Registry SchUseStrongCrypto
        {
            Key       = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName = 'SchUseStrongCrypto'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        <#Registry SchUseStrongCrypto64
        {
            Key                         = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }#>

        SqlAlias AddSqlAlias
        {
            Ensure               = "Present"
            Name                 = $SQLAlias
            ServerName           = $SQLName
            Protocol             = "TCP"
            TcpPort              = 1433
        }

        #**********************************************************
        # Join AD forest
        #**********************************************************
        # If WaitForADDomain does not find the domain whtin "WaitTimeout" secs, it will signar a restart to DSC engine "RestartCount" times
        WaitForADDomain DscForestWait
        {
            DomainName              = $DomainFQDN
            WaitTimeout             = 1200
            RestartCount            = 2
            WaitForValidCredentials = $True
            PsDscRunAsCredential    = $DomainAdminCredsQualified
            DependsOn               = "[DnsServerAddress]SetDNS"
        }

        # WaitForADDomain sets reboot signal only if WaitForADDomain did not find domain within "WaitTimeout" secs
        PendingReboot RebootOnWaitForADDomainSignal
        {
            Name             = "RebootOnWaitForADDomainSignal"
            SkipCcmClientSDK = $true
            DependsOn        = "[WaitForADDomain]DscForestWait"
        }

        Computer DomainJoin
        {
            Name       = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn  = "[PendingReboot]RebootOnWaitForADDomainSignal"
        }

        PendingReboot RebootOnComputerSignal
        {
            Name             = "RebootOnComputerSignal"
            SkipCcmClientSDK = $true
            DependsOn        = "[Computer]DomainJoin"
        }

        Group AddSPSetupAccountToAdminGroup
        {
            GroupName            = "Administrators"
            Ensure               = "Present"
            MembersToInclude     = @("$($SPSetupCredsQualified.UserName)")
            Credential           = $DomainAdminCredsQualified
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[Computer]DomainJoin"
        }

        # This script might fix an issue that occured because VM did not reboot after it joined the domain.
        # xScript CreateWSManSPNsIfNeeded
        # {
        #     SetScript =
        #     {
        #         # A few times, deployment failed because of this error:
        #         # "The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer because the computer is not trusted."
        #         # The root cause was that SPNs WSMAN/SP and WSMAN/sp.contoso.local were missing in computer account contoso\SP
        #         # Those SPNs are created by WSMan when it (re)starts
        #         # Restarting service causes an error, so creates SPNs manually instead
        #         # Restart-Service winrm

        #         # Create SPNs WSMAN/SP and WSMAN/sp.contoso.local
        #         $domainFQDN = $using:DomainFQDN
        #         $computerName = $using:ComputerName
        #         Write-Verbose -Message "Adding SPNs 'WSMAN/$computerName' and 'WSMAN/$computerName.$domainFQDN' to computer '$computerName'"
        #         setspn.exe -S "WSMAN/$computerName" "$computerName"
        #         setspn.exe -S "WSMAN/$computerName.$domainFQDN" "$computerName"
        #     }
        #     GetScript = { }
        #     # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        #     TestScript = 
        #     {
        #         $computerName = $using:ComputerName
        #         $samAccountName = "$computerName$"
        #         if ((Get-ADComputer -Filter {(SamAccountName -eq $samAccountName)} -Property serviceprincipalname | Select-Object serviceprincipalname | Where-Object {$_.ServicePrincipalName -like "WSMAN/$computerName"}) -ne $null) {
        #             # SPN is present
        #             return $true
        #         }
        #         else {
        #             # SPN is missing and must be created
        #             return $false
        #         }
        #     }
        #     DependsOn = "[PendingReboot]RebootOnComputerSignal"
        # }

        #********************************************************************
        # Wait for SharePoint app server to be ready
        #********************************************************************
        # The best test is to check a HTTP team site that is not the root, so we know that web app was already extended
        # Not testing HTTPS avoid potential issues with the root CA cert maybe not present in the machine store yet
        xScript WaitForWebAppContentDatabase
        {
            SetScript =
            {
                $uri = "http://$($using:SPTrustedSitesName)/sites/team"
                $sleepTime = 10
                $statusCode = 0
                do {
                    try
                    {
                        Write-Verbose "Trying to connect to $uri..."
                        $Response = Invoke-WebRequest -Uri $uri -ErrorAction Stop
                        # This will only execute if the Invoke-WebRequest is successful.
                        $statusCode = $Response.StatusCode
                    }
                    catch [System.Net.WebException]
                    {
                        # it should fail with StatusCode 404 until the team site is actually created, which means that web app was already extended
                        Write-Verbose "Request failed with a WebException: $($_.Exception)"
                        if ($null -ne $_.Exception.Response) {
                            $statusCode = $_.Exception.Response.StatusCode.value__
                        }
                    }
                    catch
                    {
                        Write-Verbose "Request failed with an exception: $($_.Exception)"
                        $statusCode = 0
                    }

                    if ($statusCode -ne 401){
                        Write-Verbose "Connection to $uri... returned status code $statusCode while 401 is expected, retrying in $sleepTime secs..."
                        Start-Sleep -Seconds $sleepTime
                    }
                    else {
                        Write-Verbose "Connection to $uri... returned expected status code $statusCode, exiting..."
                    }
                } while ($statusCode -ne 401)
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[Group]AddSPSetupAccountToAdminGroup"
        }

        # xScript WaitForAppServer
        # {
        #     SetScript =
        #     {
        #         $retry = $true
        #         $retrySleep = $using:RetryIntervalSec
        #         $serverName = $using:DCName
        #         $fileName = "SPDSCFinished.txt"
        #         $fullPath = "\\$serverName\C$\Setup\$fileName"
        #         while ($retry) {
        #             if ((Get-Item $fullPath -ErrorAction SilentlyContinue) -ne $null){   
        #                 $retry = $false
        #             }
        #             Write-Verbose "File '$fullPath' not found on server '$serverName', retry in $retrySleep secs..."
        #             Start-Sleep -s $retrySleep
        #         }
        #     }
        #     GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
        #     TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
        #     PsDscRunAsCredential = $DomainAdminCredsQualified
        #     DependsOn            = "[SPDistributedCacheService]EnableDistributedCache"
        # }

        <# Should not join farm before Intranet zone is created on first server, otherwise web application may not provision correctly in FE
        xScript WaitForHTTPSSite
        {
            SetScript =
            {
                $retrySleep = $using:RetryIntervalSec
                $url = "https://$($using:SPTrustedSitesName).$($using:DomainFQDN)"
                $retry = $true
                while ($retry) {
                    try {
                        Invoke-WebRequest -Uri $url -UseBasicParsing
                        $retry = $false
                    }
                    catch {
                        Write-Verbose "Connection to $url failed, retry in $retrySleep secs..."
                        Start-Sleep -s $retrySleep
                    }
                }
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[xScript]WaitForWebAppContentDatabase"
        }#>

        

        #**********************************************************
        # Join SharePoint farm
        #**********************************************************
        SPFarm JoinSPFarm
        {
            DatabaseServer            = $SQLAlias
            FarmConfigDatabaseName    = $SPDBPrefix + "Config"
            Passphrase                = $SPPassphraseCreds
            FarmAccount               = $SPFarmCredsQualified
            PsDscRunAsCredential      = $SPSetupCredsQualified
            AdminContentDatabaseName  = $SPDBPrefix + "AdminContent"
            CentralAdministrationPort = 5000
            # If RunCentralAdmin is false and configdb does not exist, SPFarm checks during 30 mins if configdb got created and joins the farm
            RunCentralAdmin           = $false
            IsSingleInstance          = "Yes"
            Ensure                    = "Present"
            DependsOn                 = "[xScript]WaitForWebAppContentDatabase"
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            CacheSizeInMB        = 2000
            CreateFirewallRules  = $true
            ServiceAccount       = $SPSvcCredsQualified.UserName
            InstallAccount       = $SPSetupCredsQualified
            Ensure               = "Present"
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        xDnsRecord UpdateDNSAliasSPSites
        {
            Name                 = $SPTrustedSitesName
            Zone                 = $DomainFQDN
            DnsServer            = $DCName
            Target               = "$ComputerName.$DomainFQDN"
            Type                 = "CName"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        xDnsRecord UpdateDNSAliasOhMy
        {
            Name                 = $MySiteHostAlias
            Zone                 = $DomainFQDN
            DnsServer            = $DCName
            Target               = "$ComputerName.$DomainFQDN"
            Type                 = "CName"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        xDnsRecord UpdateDNSAliasHNSC1
        {
            Name                 = $HNSC1Alias
            Zone                 = $DomainFQDN
            DnsServer            = $DCName
            Target               = "$ComputerName.$DomainFQDN"
            Type                 = "CName"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        # Update GPO to ensure the root certificate of the CA is present in "cert:\LocalMachine\Root\" before issuing a certificate request, otherwise request would fail
        xScript UpdateGPOToTrustRootCACert
        {
            SetScript =
            {
                gpupdate.exe /force
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false }
            DependsOn            = "[SPFarm]JoinSPFarm"
            PsDscRunAsCredential = $DomainAdminCredsQualified
        }

        CertReq SPSSiteCert
        {
            CARootName             = "$DomainNetbiosName-$DCName-CA"
            CAServerFQDN           = "$DCName.$DomainFQDN"
            Subject                = "$SPTrustedSitesName.$DomainFQDN"
            SubjectAltName         = "dns=*.$DomainFQDN&dns=*.$AppDomainIntranetFQDN"
            KeyLength              = '2048'
            Exportable             = $true
            ProviderName           = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                    = '1.3.6.1.5.5.7.3.1'
            KeyUsage               = '0xa0'
            CertificateTemplate    = 'WebServer'
            AutoRenew              = $true
            Credential             = $DomainAdminCredsQualified
            DependsOn              = "[xScript]UpdateGPOToTrustRootCACert"
        }

        xWebsite SetHTTPSCertificate
        {
            Name                 = "SharePoint - 443"
            BindingInfo          = MSFT_xWebBindingInformation
            {
                Protocol             = "HTTPS"
                Port                 = 443
                CertificateStoreName = "My"
                CertificateSubject   = "$SPTrustedSitesName.$DomainFQDN"
            }
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[CertReq]SPSSiteCert"
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

<#
# Azure DSC extension logging: C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.21.0.0
# Azure DSC extension configuration: C:\Packages\Plugins\Microsoft.Powershell.DSC\2.21.0.0\DSCWork

Install-Module -Name xPendingReboot
help ConfigureFEVM

$DomainAdminCreds = Get-Credential -Credential "yvand"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$SPFarmCreds = Get-Credential -Credential "spfarm"
$SPSvcCreds = Get-Credential -Credential "spsvc"
$SPPassphraseCreds = Get-Credential -Credential "Passphrase"
$SPSuperUserCreds = Get-Credential -Credential "spSuperUser"
$SPSuperReaderCreds = Get-Credential -Credential "spSuperReader"
$DNSServer = "10.0.1.4"
$DomainFQDN = "contoso.local"
$DCName = "DC"
$SQLName = "SQL"
$SQLAlias = "SQLAlias"

$outputPath = "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.80.1.0\DSCWork\ConfigureFEVM.0\ConfigureFEVM"
ConfigureFEVM -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPSvcCreds $SPSvcCreds -SPPassphraseCreds $SPPassphraseCreds -DNSServer $DNSServer -DomainFQDN $DomainFQDN -DCName $DCName -SQLName $SQLName -SQLAlias $SQLAlias -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath $outputPath
Set-DscLocalConfigurationManager -Path $outputPath
Start-DscConfiguration -Path $outputPath -Wait -Verbose -Force

#>
