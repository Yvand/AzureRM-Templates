configuration ConfigureDCVM 
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
    
    Import-DscResource -ModuleName xActiveDirectory,xDisk, xNetworking, cDisk, xPSDesiredStateConfiguration, xAdcsDeployment, xCertificate
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$DomainCredsNetbios = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$AdfsSvcCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($AdfsSvcCreds.UserName)", $AdfsSvcCreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

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
            DomainAdministratorCredential = $DomainCredsNetbios
            SafemodeAdministratorPassword = $DomainCredsNetbios
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
	        DependsOn = "[WindowsFeature]ADDSInstall"
        }

        #**********************************************************
        # Misc: Set email of AD domain admin and add remote AD tools
        #**********************************************************
        xADUser SetEmailOfDomainAdmin
        {
            DomainAdministratorCredential = $DomainCredsNetbios
            DomainName = $DomainName
            UserName = $Admincreds.UserName
            Password = $Admincreds
            EmailAddress = $Admincreds.UserName + "@" + $DomainName
            PasswordAuthentication = 'Negotiate'
            Ensure = "Present"
            DependsOn = "[xADDomain]FirstDS"
        }
        WindowsFeature AddADFeature1    { Name = "RSAT-ADLDS";          Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }
        WindowsFeature AddADFeature2    { Name = "RSAT-ADDS-Tools";     Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }

        #**********************************************************
        # Configure AD CS
        #**********************************************************
        WindowsFeature AddCertAuthority { Name = "ADCS-Cert-Authority"; Ensure = "Present"; DependsOn = "[xADDomain]FirstDS" }
        xADCSCertificationAuthority ADCS
        {
            Ensure = "Present"
            Credential = $DomainCredsNetbios
            CAType = "EnterpriseRootCA"
            DependsOn = "[WindowsFeature]AddCertAuthority"              
        }
        
        #**********************************************************
        # Configure AD FS
        #**********************************************************
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
			#SubjectAltName            = "certauth.ADFS.$DomainName"
            Credential                = $DomainCredsNetbios
            DependsOn = '[xADCSCertificationAuthority]ADCS'
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
            DependsOn = '[xADCSCertificationAuthority]ADCS'
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
            DependsOn = '[xADCSCertificationAuthority]ADCS'
        }        

        xADUser CreateAdfsSvcAccount
        {
            DomainAdministratorCredential = $DomainCredsNetbios
            DomainName = $DomainName
            UserName = $AdfsSvcCreds.UserName
            Password = $AdfsSvcCreds
            Ensure = "Present"
            PasswordAuthentication = 'Negotiate'
            DependsOn = "[xCertReq]ADFSSiteCert", "[xCertReq]ADFSSigningCert", "[xCertReq]ADFSDecryptionCert"
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

        WindowsFeature AddADFS          { Name = "ADFS-Federation"; Ensure = "Present"; DependsOn = "[Group]AddAdfsSvcAccountToDomainAdminsGroup" }
        <#
        xScript CreateADFSFarm
        {
            SetScript = 
            {
                Write-Verbose -Message "Creating ADFS farm 'ADFS.$using:DomainName'"

                $Key = [byte]1..16
                $using:AdfsSvcCredsQualified.Password | ConvertFrom-SecureString -Key $Key | Set-Content c:\cred.key

                $ScriptBlock = {
                    param
                    (
                        [string]$DomainName = $args[0],
                        [string]$AdfsSvcUsernameQualified = $args[1]
                    )
                    function CreateADFSFarm
                    {
                        $Key = [byte]1..16
                        $encrypted = Get-Content c:\cred.key | ConvertTo-SecureString -Key $Key
                        $AdfsSvcCredsQualified = New-Object System.Management.Automation.PsCredential($AdfsSvcUsernameQualified, $encrypted)

                        $siteCert = Get-ChildItem -Path """cert:\LocalMachine\My\""" -DnsName """ADFS.$DomainName"""
		                $signingCert = Get-ChildItem -Path """cert:\LocalMachine\My\""" -DnsName """ADFS.Signing"""
		                $decryptionCert = Get-ChildItem -Path """cert:\LocalMachine\My\""" -DnsName """ADFS.Decryption"""

                        New-Item """C:\new_file.txt""" -type file -force -value """Creating ADFS farm 'ADFS.$DomainName' as $AdfsSvcUsernameQualified sitecert $sitecert $signingCert $decryptionCert"""

		                $runParams = @{}
		                $runParams.Add("""CertificateThumbprint""", $siteCert.Thumbprint)
		                $runParams.Add("""FederationServiceName""", """ADFS.$DomainName""")
		                $runParams.Add("""ServiceAccountCredential""", $AdfsSvcCredsQualified)
		                $runParams.Add("""SigningCertificateThumbprint""", $signingCert.Thumbprint)
		                $runParams.Add("""DecryptionCertificateThumbprint""", $decryptionCert.Thumbprint)
		                Install-AdfsFarm @runParams -OverwriteConfiguration
                    }
                }

                $stdOutLog = "C:\stdout.log"
                $stdErrLog = "C:\stderr.log"
                Start-Process -LoadUserProfile -Wait -FilePath $PSHOME\powershell.exe -ArgumentList "-Command & {$ScriptBlock CreateADFSFarm}", "$using:DomainName", $using:AdfsSvcCredsQualified.UserName -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog
                Write-Verbose -Message "ADFS farm successfully created"
            }
            GetScript =  
            {
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
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
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
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
            DependsOn = "[WindowsFeature]AddADFS"
        }
        
		xScript CreateADFSRelyingParty
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
                # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
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
                # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
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
            DependsOn = "[xScript]CreateADFSFarm"
        }
        #>
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

<#
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name xAdcsDeployment
Install-Module -Name xCertificate
Install-Module -Name xPSDesiredStateConfiguration
Install-Module -Name xCredSSP
Install-Module -Name xWebAdministration
Install-Module -Name xDisk
Install-Module -Name xNetworking

help ConfigureDCVM

$Admincreds = Get-Credential -Credential "yvand"
$AdfsSvcCreds = Get-Credential -Credential "adfssvc"
$DomainFQDN = "contoso.local"

ConfigureDCVM -Admincreds $Admincreds -AdfsSvcCreds $AdfsSvcCreds -DomainName $DomainFQDN -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath "C:\Data\\output"
Set-DscLocalConfigurationManager -Path "C:\Data\output\"
Start-DscConfiguration -Path "C:\Data\output" -Wait -Verbose -Force

https://github.com/PowerShell/xActiveDirectory/issues/27
Uninstall-WindowsFeature "ADFS-Federation"
https://msdn.microsoft.com/library/mt238290.aspx
\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query
#>
