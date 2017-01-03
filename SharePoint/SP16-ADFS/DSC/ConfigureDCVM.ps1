configuration CreateADPDC 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdfsSvcCreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30,
        [String]$ADFSRelyingPartyTrustName = "SPSites"
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory,xDisk, xNetworking, cDisk, PSDesiredStateConfiguration, xAdcsDeployment, xCertificate
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$DomainCredsNetbios = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$AdfsSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($AdfsSvcCreds.UserName)", $AdfsSvcCreds.Password)
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
        xADUser SetEmailOfDomainAdmin
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $Admincreds.UserName
            Password = $Admincreds
            EmailAddress = $Admincreds.UserName + "@" + $DomainName
            Ensure = "Present"
            DependsOn = "[xADDomain]FirstDS"
        }

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
        
        xCertReq ADFSSiteCert
        {
            CARootName                = $DomainNetbiosName + "-DC-CA"
            CAServerFQDN              = "dc." + $DomainName
            Subject                   = "ADFS." + $DomainName
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainCredsNetbios
            DependsOn = '[WindowsFeature]AddCertAuthority'
        }

        xCertReq ADFSSigningCert
        {
            CARootName                = $DomainNetbiosName + "-DC-CA"
            CAServerFQDN              = "dc." + $DomainName
            Subject                   = "ADFS.Signing"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainCredsNetbios
            DependsOn = '[WindowsFeature]AddCertAuthority'
        }
        
        xCertReq ADFSDecryptionCert
        {
            CARootName                = $DomainNetbiosName + "-DC-CA"
            CAServerFQDN              = "dc." + $DomainName
            Subject                   = "ADFS.Decryption"
            KeyLength                 = '2048'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainCredsNetbios
            DependsOn = '[WindowsFeature]AddCertAuthority'
        }
        
        WindowsFeature AddADFS          { Name = "ADFS-Federation"; Ensure = "Present"; DependsOn = "[WindowsFeature]AddCertAuthority" }

        xADUser CreateAdfsSvcAccount
        {
            DomainAdministratorCredential = $DomainCredsNetbios
            DomainName = $DomainName
            UserName = $AdfsSvcCreds.UserName
            Password = $AdfsSvcCreds
            Ensure = "Present"
            DependsOn = "[xADDomain]FirstDS"
        }

        Group AddAdfsSvcAccountToDomainAdminsGroup
        {
            GroupName='Administrators'   
            Ensure= 'Present'             
            MembersToInclude= $AdfsSvcCredsQualified.UserName
            Credential = $DomainCredsNetbios    
            PsDscRunAsCredential = $DomainCredsNetbios
            DependsOn = "[xADUser]CreateAdfsSvcAccount"
        }

        Script CreateADFSFarm
        {
            SetScript = 
            {
                Write-Verbose -Message "Creating ADFS farm 'ADFS.$using:DomainName'"
                $siteCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "ADFS.$using:DomainName"
                $signingCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "ADFS.Signing"
                $decryptionCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "ADFS.Decryption"
                Install-AdfsFarm -CertificateThumbprint $siteCert.Thumbprint `
                    -FederationServiceName "ADFS.$using:DomainName" `
                    -ServiceAccountCredential $using:AdfsSvcCredsQualified `
                    -SigningCertificateThumbprint $signingCert.Thumbprint `
                    -DecryptionCertificateThumbprint $decryptionCert.Thumbprint `
                    -OverwriteConfiguration
                Write-Verbose -Message "ADFS farm successfully created"
            }
            GetScript =  
            {
                $result = "true"
                try
                {
                    Get-AdfsProperties
                }
                catch
                {
                    $result = "false"
                }
                return @{ "Result" = $result }
            }
            TestScript = 
            {
                try
                {
                    Get-AdfsProperties
                    Write-Verbose -Message "ADFS farm already exists"
                    return $true
                }
                catch
                {
                    Write-Verbose -Message "ADFS farm does not exist"
                    return $false
                }
            }
            PsDscRunAsCredential = $DomainCredsNetbios
            DependsOn = "[Group]AddAdfsSvcAccountToDomainAdminsGroup"
        }

        Script CreateADFSRelyingParty
        {
            SetScript = 
            {
                Write-Verbose -Message "Creating Relying Party '$using:ADFSRelyingPartyTrustName' in ADFS farm"
                Add-ADFSRelyingPartyTrust -Name $using:ADFSRelyingPartyTrustName `
                    -Identifier "https://$using:ADFSRelyingPartyTrustName.$using:DomainName" `
                    -ClaimsProviderName "Active Directory" `
                    -Enabled $true `
                    -WSFedEndpoint "https://$using:ADFSRelyingPartyTrustName.$using:DomainName/_trust/" `
                    -IssuanceAuthorizationRules '=> issue (Type = "http://schemas.microsoft.com/authorization/claims/permit", value = "true");' `
                    -Confirm:$false 
                Write-Verbose -Message "Relying Party '$using:ADFSRelyingPartyTrustName' successfully created"
            }
            GetScript =  
            {
                $result = "false"
                $rpFound = Get-ADFSRelyingPartyTrust -Name $using:ADFSRelyingPartyTrustName                
                if ($rpFound -ne $null)
                {
                    $result = "true"
                }
                return @{ "Result" = $result }
            }
            TestScript = 
            {
                $rpFound = Get-ADFSRelyingPartyTrust -Name $using:ADFSRelyingPartyTrustName                
                if ($rpFound -ne $null)
                {
                    Write-Verbose -Message "Relying Party '$using:ADFSRelyingPartyTrustName' already exists"
                    return $true
                }
                Write-Verbose -Message "Relying Party '$using:ADFSRelyingPartyTrustName' does not exist"
                return $false
            }
            PsDscRunAsCredential = $DomainCredsNetbios
            DependsOn = "[Script]CreateADFSFarm"
        }
   }
}

function Get-NetBIOSName
{
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
} 

CreateADPDC -Admincreds $Admincreds -AdfsSvcCreds $AdfsSvcCreds -DomainName $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

<#
help CreateADPDC

$Admincreds = Get-Credential -Credential "yvand"
$AdfsSvcCreds = Get-Credential -Credential "AdfsSvcCreds"
$DomainFQDN = "contoso.local"

CreateADPDC -Admincreds $Admincreds -AdfsSvcCreds $AdfsSvcCreds -DomainName $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

Uninstall-WindowsFeature "ADFS-Federation"
https://msdn.microsoft.com/library/mt238290.aspx
\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query
#>
