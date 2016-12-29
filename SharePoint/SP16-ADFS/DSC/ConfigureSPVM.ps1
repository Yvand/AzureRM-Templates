configuration ConfigureSPVMStage2
{
    param
    (
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
        [System.Management.Automation.PSCredential]$SPPassphraseCreds
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xCredSSP, xWebAdministration, SharePointDsc, xPSDesiredStateConfiguration

    [System.Management.Automation.PSCredential]$DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential]$SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential]$SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPFarmCreds.UserName)", $SPSetupCreds.Password)
    [Int]$RetryCount = 30
    [Int]$RetryIntervalSec = 60
    [String]$SPDBPrefix = "SP16DSC_"

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainFQDN
            DomainUserCredential= $DomainAdminCredsQualified
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xComputer]DomainJoin" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = "*.$DomainFQDN", "localhost"; DependsOn = "[xComputer]DomainJoin" }

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[xComputer]DomainJoin"}

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

        File PreSPConfigDone
        {
            DestinationPath = "F:\Logs\DSC1.txt"
            PsDscRunAsCredential = $SPSetupCredential
            Contents = "DSC Pre-SharePoint config done"
            Type = 'File'
            Force = $true
            DependsOn = "[Group]AddSPSetupAccountToAdminGroup", "[xADUser]CreateSParmAccount"
        }

        
        #**********************************************************
        # SharePoint configuration
        #**********************************************************
        xRemoteFile Download201612CU
        {  
            Uri             = "https://download.microsoft.com/download/D/0/4/D04FD356-E140-433E-94F6-472CF45FD591/sts2016-kb3128014-fullfile-x64-glb.exe"
            DestinationPath = "F:\setup\sts2016-kb3128014-fullfile-x64-glb.exe"
            MatchSource = $false
            DependsOn = "[File]PreSPConfigDone"
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
            DependsOn = "[xRemoteFile]Download201612CU"
        }
        
        SPCreateFarm CreateSPFarm
        {
            DatabaseServer           = "sql"
            FarmConfigDatabaseName   = $SPDBPrefix+"Config"
            Passphrase               = $SPPassphraseCreds
            FarmAccount              = $SPFarmCredsQualified
            PsDscRunAsCredential     = $SPSetupCredsQualified
            AdminContentDatabaseName = $SPDBPrefix+"AdminContent"
            CentralAdministrationPort = 5000
            DependsOn = "[xPackage]Install201612CU"
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


ConfigureSPVMStage2 -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPPassphraseCreds $SPPassphraseCreds -DomainFQDN $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

<#
$DomainAdminCreds = Get-Credential -Credential "yvand"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$SPFarmCreds = Get-Credential -Credential "spfarm"
$SPPassphraseCreds = Get-Credential -Credential "Passphrase"
$DomainFQDN = "contoso.local"

ConfigureSPVMStage2 -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPPassphraseCreds $SPPassphraseCreds -DomainFQDN $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
help ConfigureSPVMStage2

Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force
#>
