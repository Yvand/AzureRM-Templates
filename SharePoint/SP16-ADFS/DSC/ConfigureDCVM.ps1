configuration CreateADPDC 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory,xDisk, xNetworking, cDisk, PSDesiredStateConfiguration, xAdcsDeployment, xCertificate
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        Script AddADDSFeature {
            SetScript = {
                Add-WindowsFeature "AD-Domain-Services" -ErrorAction SilentlyContinue   
            }
            GetScript =  { @{} }
            TestScript = { $false }
        }
	
	    WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"		
        }

        Script script1
	    {
      	    SetScript =  { 
		        Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics" 
            }
            GetScript =  { @{} }
            TestScript = { $false }
	        DependsOn = "[WindowsFeature]DNS"
        }

	    WindowsFeature DnsTools
	    {
	        Ensure = "Present"
            Name = "RSAT-DNS-Server"
	    }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
	        DependsOn = "[WindowsFeature]DNS"
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
	        DependsOn="[cDiskNoRestart]ADDataDisk", "[Script]AddADDSFeature"
        } 
         
        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
	        DependsOn = "[WindowsFeature]ADDSInstall"
        } 

        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Yvand custom
        #**********************************************************
        WindowsFeature AddADFeature1    { Name = "RSAT-ADLDS";          Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }
        WindowsFeature AddADFeature2    { Name = "RSAT-ADDS-Tools";     Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }
        WindowsFeature AddCertAuthority { Name = "ADCS-Cert-Authority"; Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }
        xADCSCertificationAuthority ADCS
        {
            Ensure = "Present"
            Credential = $DomainCreds
            CAType = "EnterpriseRootCA"
            DependsOn = "[WindowsFeature]AddCertAuthority"              
        }

        xADCSWebEnrollment CertSrv
        {
            IsSingleInstance = 'Yes'
            Ensure = 'Present'
            Credential = $DomainCreds
            DependsOn = '[xADCSCertificationAuthority]ADCS'
        }

        xCertReq SSLCert
        {
            CARootName                = 'contoso-DC-CA'
            CAServerFQDN              = 'dc.contoso.local'
            Subject                   = 'ADFS.contoso.local'
            KeyLength                 = '1024'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainCreds
            DependsOn = '[xADCSWebEnrollment]CertSrv'
        }

        
        
        WindowsFeature AddADFS          { Name = "ADFS-Federation"; Ensure = "Present"; DependsOn = "[xADCSCertificationAuthority]ADCS" }
   }
} 

CreateADPDC -Admincreds $Admincreds -DomainName $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

<#
help CreateADPDC

$Admincreds = Get-Credential -Credential "yvand"
$DomainFQDN = "contoso.local"

CreateADPDC -Admincreds $Admincreds -DomainName $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

#>
