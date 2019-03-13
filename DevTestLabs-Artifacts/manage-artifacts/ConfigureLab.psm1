<#
.SYNOPSIS
This script creates a new environment in the lab using an existing environment template.
 
.PARAMETER pathToPackage
   The full path to the claims provider WSP package.
.PARAMETER claimsProviderName
   The name of the claims provider.
.PARAMETER spTrustName
   The name of the SPTrusedLoginProvider.
.PARAMETER adminUserName
   The name of SharePoint admin account that will install the claims provider.
.PARAMETER adminPassword
   The password of SharePoint admin account.
 
.NOTES
The script assumes that the claims provider WSP package exists, and that it is not already installed.
#>

function Configure-Lab
{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The full path to the claims provider WSP package.")]
        [string] $pathToPackage,
        [Parameter(Mandatory=$true, HelpMessage=" The name of the claims provider.")]
        [string] $claimsProviderName,
        [Parameter(Mandatory=$true, HelpMessage="The name of the SPTrusedLoginProvider.")]
        [string] $spTrustName,
        [Parameter(Mandatory=$true, HelpMessage="The name of SharePoint admin account that will install the claims provider.")]
        [string] $adminUserName,
        [Parameter(Mandatory=$true, HelpMessage="The password of SharePoint admin account.")]
        [string] $adminPassword
    )

    # Ensure we set the working directory to that of the script.
    Push-Location $PSScriptRoot

    try
    {
        Write-Host "Populating Active Directory..."
        Populate-ActiveDirectory -adminUserName $adminUserName -adminPassword $adminPassword

        $tryCount = 0
        $success = $false
        do
        {
            try
            {
                $tryCount++
                Write-Host "Attempt $tryCount to install claims provider '$claimsProviderName'..."
                Install-ClaimsProvider @PSBoundParameters
                $success = $true
            }
            catch
            {
                RemoveAndClean-ClaimsProviderSolution -pathToPackage $pathToPackage -claimsProviderName $claimsProviderName -adminUserName $adminUserName -adminPassword $adminPassword
            }
        } # Attempt installation 2 times maximum
        while ($success -eq $false -and $tryCount -le 2)        
    }
    finally
    {
        Pop-Location
    }
}

<#
.SYNOPSIS
Install and deploy custom claims provider to the SharePoint farm
#>
function Install-ClaimsProvider
{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The full path to the claims provider WSP package.")]
        [string] $pathToPackage,
        [Parameter(Mandatory=$true, HelpMessage=" The name of the claims provider.")]
        [string] $claimsProviderName,
        [Parameter(Mandatory=$true, HelpMessage="The name of the SPTrusedLoginProvider.")]
        [string] $spTrustName,
        [Parameter(Mandatory=$true, HelpMessage="The name of SharePoint admin account that will install the claims provider.")]
        [string] $adminUserName,
        [Parameter(Mandatory=$true, HelpMessage="The password of SharePoint admin account.")]
        [string] $adminPassword
    )

    try
    {
        $PSBoundParameters.Add("scriptRoot", $PSScriptRoot)
        $securePassword = $adminPassword | ConvertTo-SecureString -AsPlainText -Force
        [System.Management.Automation.PSCredential] $adminCreds = New-Object System.Management.Automation.PSCredential ($adminUserName, $securePassword)

        Write-Host "Calling Invoke-SPDSCCommand as $($adminCreds.UserName)..."
        Invoke-SPDSCCommand -Credential $adminCreds `
                            -Arguments $PSBoundParameters `
                            -ScriptBlock {
            $params = $args[0]

            $packateLiteralPath = Join-Path -Path $($params.scriptRoot) -ChildPath $($params.pathToPackage) -Resolve
            $packageName = "$($params.claimsProviderName).wsp"
            Write-Host "Adding solution $packageName to the farm..."
            Add-SPSolution -LiteralPath $packateLiteralPath    

            $maxCount = 20
            $count = 0
            while (($count -lt $maxCount) -and ($null -eq $solution))
            {
                Write-Host "Waiting for solution $packageName to be added to the farm..."
                Start-Sleep -Seconds 5
                $solution = Get-SPSolution -Identity $packageName
                $count++
            }

            if ($null -eq $solution) {
                Write-Error "Installation of solution $packageName failed."
                throw ("Installation of solution $packageName failed.")
            }

            # Always wait at least 5 seconds to avoid that Install-SPSolution does not actually trigger deployment
            Start-Sleep -Seconds 5
            Write-Host "Deploying solution $packageName to the farm..."
            Install-SPSolution -Identity $packageName -GACDeployment
            $solution = Get-SPSolution -Identity $packageName
            
            $count = 0
            while (($count -lt $maxCount) -and $solution.LastOperationResult -eq [Microsoft.SharePoint.Administration.SPSolutionOperationResult]::NoOperationPerformed )
            {
                Write-Host "Waiting for solution $packageName to deploy on the farm..."
                Start-Sleep -Seconds 5
                $solution = Get-SPSolution -Identity $packageName
                $solution.SPSolutionOperationResult
                $count++
            }

            if ($false -eq $solution.Deployed -or $solution.LastOperationResult -ne [Microsoft.SharePoint.Administration.SPSolutionOperationResult]::DeploymentSucceeded ) {
                Write-Error "Deployment of solution $packageName failed: $($solution.LastOperationResult ). $($solution.LastOperationDetails)"
                throw ("Deployment of solution $packageName failed: $($solution.LastOperationResult ). $($solution.LastOperationDetails)")
            }

            Write-Host "Solution $packageName is deployed, associating $($params.claimsProviderName) to the SPTrust $($params.spTrustName)..."
            $trust = Get-SPTrustedIdentityTokenIssuer ($params.spTrustName)
            $trust.ClaimProviderName = ($params.claimsProviderName)
            $trust.Update()
            Write-Host "Solution $packageName was deployed successfully and claims provider $($params.claimsProviderName) was associated to the SPTrust $($params.spTrustName)." -ForegroundColor Green    
        }
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        Write-Error "Installation of claims provider failed with error '$errorMessage'. $($_.Exception)"
        throw ("Installation of claims provider failed with error '$errorMessage'. $($_.Exception)")
    }
    finally
    {
    }
}

<#
.SYNOPSIS
If install of SharePoint solution failed, this function will properly remove it from the farm
#>
function RemoveAndClean-ClaimsProviderSolution
{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The full path to the claims provider WSP package.")]
        [string] $pathToPackage,
        [Parameter(Mandatory=$true, HelpMessage=" The name of the claims provider.")]
        [string] $claimsProviderName,
        [Parameter(Mandatory=$true, HelpMessage="The name of SharePoint admin account that will install the claims provider.")]
        [string] $adminUserName,
        [Parameter(Mandatory=$true, HelpMessage="The password of SharePoint admin account.")]
        [string] $adminPassword
    )

    try
    {
        $PSBoundParameters.Add("scriptRoot", $PSScriptRoot)
        $securePassword = $adminPassword | ConvertTo-SecureString -AsPlainText -Force
        [System.Management.Automation.PSCredential] $adminCreds = New-Object System.Management.Automation.PSCredential ($adminUserName, $securePassword)

        Write-Host "Calling Invoke-SPDSCCommand as $($adminCreds.UserName)..."
        Invoke-SPDSCCommand -Credential $adminCreds `
                            -Arguments $PSBoundParameters `
                            -ScriptBlock {
            $params = $args[0]
            $claimsProviderName = $params.claimsProviderName
            $pathToPackage = $params.pathToPackage
            # Working location must be pushed again to import current module, since it is reset in Invoke-SPDSCCommand
            Push-Location $params.scriptRoot
            Import-Module -Name ".\ConfigureLab.psm1"

            Write-Host "Starting clean removal of claims provider '$claimsProviderName' from the farm..."
            $cpFeatures = Get-SPFeature| ?{$_.DisplayName -like "$claimsProviderName*"}
            foreach ($cpFeature in $cpFeatures) {
                Generate-FeatureFileDefinition -cpFeature $cpFeature
            }

            Write-Host "Remove SPClaimProvider $claimsProviderName if found in the farm..."
            Get-SPClaimProvider| ?{$_.DisplayName -like "$claimsProviderName"}| Remove-SPClaimProvider

            # Disable may fail if features were not enabled, just try and ignore if it fails
            Write-Host "Disabling all features with DisplayName -like '$claimsProviderName*'..."
            Get-SPFeature| ?{$_.DisplayName -like "$claimsProviderName*"}| Disable-SPFeature -Confirm:$false -ErrorAction SilentlyContinue

            # Uninstall features
            Write-Host "Uninstalling all features with DisplayName -like '$claimsProviderName*'..."
            Get-SPFeature| ?{$_.DisplayName -like "$claimsProviderName*"}| Uninstall-SPFeature -Confirm:$false

            $wspFileName = Split-Path $pathToPackage -Leaf
            Write-Host "Removing solution $wspFileName..."
            Remove-SPSolution -Identity "$wspFileName" -Confirm:$false
        }
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        Write-Error "Removal of claims provider failed with error '$errorMessage'. $($_.Exception)"
        throw ("Removal of claims provider failed with error '$errorMessage'. $($_.Exception)")
    }
    finally
    {
    }
}

function Generate-FeatureFileDefinition {
	[CmdletBinding()]Param (
		[Microsoft.SharePoint.Administration.SPFeatureDefinition]$cpFeature
	)
    
    $xmldata = @"
<?xml version="1.0" encoding="utf-8"?>
<Feature xmlns="http://schemas.microsoft.com/sharepoint/" Creator="Yvan Duhamel" Description="TEMP FEATURE CREATED TO ALLOW ITS PROPER DELETION FROM THE FARM" Id="%%FEATUREID%%" Scope="%%FEATURESCOPE%%" Title="%%FEATURETITLE%%" Version="1.0.0.0">
</Feature>
"@
    
    # Create directory if it does not exist
    if ((Test-Path $cpFeature.RootDirectory) -eq $false) {
        Write-Host "Creating missing directory '$($cpFeature.RootDirectory)' for feature '$($cpFeature.DisplayName)'"
        New-Item -ItemType Directory -Path $cpFeature.RootDirectory | Out-Null
    }

    $configxml = [xml] $xmldata
    $configxml.Feature.Id = $cpFeature.Id.ToString()
    # cpFeature.Scope may be null, assume it is farm if so
    $scope = "Farm"
    if ($cpFeature.Scope -ne $null) {
        $scope = $cpFeature.Scope.ToString()
    }
    $configxml.Feature.Scope = $scope
    $configxml.Feature.Title = $cpFeature.DisplayName
    #$configxml.SelectSingleNode("/Feature")
    
    $destinationFilePath = Join-Path -Path $cpFeature.RootDirectory -ChildPath "feature.xml"
    Write-Host "Saving file '$destinationFilePath' with XML content '$($configXml.OuterXml)'..."
    $configXml.Save($destinationFilePath)    
}

<#
.SYNOPSIS
Create and update objects in Active Directory
#>
function Populate-ActiveDirectory
{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The name of SharePoint admin account.")]
        [string] $adminUserName,
        [Parameter(Mandatory=$true, HelpMessage="The password of SharePoint admin account.")]
        [string] $adminPassword
    )

    $PSBoundParameters.Add("scriptRoot", $PSScriptRoot)
    $securePassword = $adminPassword | ConvertTo-SecureString -AsPlainText -Force
    [System.Management.Automation.PSCredential] $adminCreds = New-Object System.Management.Automation.PSCredential ($adminUserName, $securePassword)

    Invoke-SPDSCCommand -Credential $adminCreds `
                        -Arguments $PSBoundParameters `
                        -ScriptBlock {
        $params = $args[0]
        # Working location must be pushed again to import current module, since it is reset in Invoke-SPDSCCommand
        Push-Location $params.scriptRoot
        Import-Module -Name ".\ConfigureLab.psm1"
        try
        {
            $adminName = "Yvand"
            $groupName = "Group1"
            $users = @( 
                @{Name = "user1"; AddToGroup = $true; OtherAttributes = @{'mail'="user1@yvand.net"; 'displayName'="user1"} }, 
                @{Name = "user2"; AddToGroup = $false; OtherAttributes = @{'mail'="user2@yvand.net"; 'displayName'="firstname user2"; 'givenName'="firstname user2"} },
                @{Name = "user3"; AddToGroup = $false; OtherAttributes = @{'mail'="user3@yvand.net"; 'displayName'="user3"} }
                    )

            if ($null -eq (Get-ADGroup -Filter {SamAccountName -eq $groupName})) {
                Write-Host "Creating AD group $groupName and adding $adminName to it..."
                New-ADGroup -Name $groupName -SamAccountName $groupName -GroupCategory Security -GroupScope Global -DisplayName $groupName
                Add-ADGroupMember -Identity $groupName -Members $adminName
            }

            foreach ($user in $users) {
                $userName = $user.Name
                Write-Host "Processing AD user $($user.Name)..."
                if ($null -eq (Get-ADUser -Filter {SamAccountName -eq $userName})) {
                    Write-Host "Creating AD user $($user.Name)..."
                    $plainPassword = Create-StrongPassword -Size 12 -Complexity ULNS -Exclude "OLIoli01"
                    $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -force
                    New-ADUser -Name $user.Name -OtherAttributes $user.OtherAttributes -AccountPassword $securePassword -Enabled $true
                }

                if ($true -eq $user.AddToGroup) {
                    Write-Host "Adding AD user $($user.Name) to group $groupName..."
                    Add-ADGroupMember -Identity $groupName -Members $user.Name
                }
            }
        }
        catch
        {
            $errorMessage = $_.Exception.Message
            Write-Error "Populate-ActiveDirectory failed with error $errorMessage. $($_.Exception)"
            throw ("Populate-ActiveDirectory failed with error '$errorMessage'. $($_.Exception)")
        }
        finally
        {
        }
    }
}

<#
.SYNOPSIS
Load SharePoint PowerShell cmdlets and run code with elevated privileges
#>
function Invoke-SPDSCCommand
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [Object[]]
        $Arguments,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    $VerbosePreference = 'Continue'

    $baseScript = @"
        if (`$null -eq (Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue))
        {
            Add-PSSnapin Microsoft.SharePoint.PowerShell
        }
"@

    $invokeArgs = @{
        ScriptBlock = [ScriptBlock]::Create($baseScript + $ScriptBlock.ToString())
    }
    if ($null -ne $Arguments)
    {
        $invokeArgs.Add("ArgumentList", $Arguments)
    }

    if ($null -eq $Credential)
    {
        if ($Env:USERNAME.Contains("$"))
        {
            throw [Exception] ("You need to specify a value for either InstallAccount " + `
                               "or PsDscRunAsCredential.")
            return
        }
        Write-Verbose -Message "Executing as the local run as user $($Env:USERDOMAIN)\$($Env:USERNAME)"

        try
        {
            $result = Invoke-Command @invokeArgs -Verbose
        }
        catch
        {
            throw $_
        }
        return $result
    }
    else
    {
        Write-Verbose -Message ("Executing using a provided credential and local PSSession " + `
                                "as user $($Credential.UserName)")

        # Running garbage collection to resolve issues related to Azure DSC extention use
        [GC]::Collect()

        $session = New-PSSession -ComputerName $env:COMPUTERNAME `
                                 -Credential $Credential `
                                 -Authentication CredSSP `
                                 -Name "DevTestLabs" `
                                 -SessionOption (New-PSSessionOption -OperationTimeout 0 `
                                                                     -IdleTimeout 60000) `
                                 -ErrorAction Continue

        if ($session)
        {
            $invokeArgs.Add("Session", $session)
        }

        try
        {
            $result = Invoke-Command @invokeArgs -Verbose
        }
        catch
        {
            throw $_
        }

        if ($session)
        {
            Remove-PSSession -Session $session
        }
        return $result
    }
}

<#
.SYNOPSIS
Creates a strong password. Copied from https://powersnippets.com/create-password/
#>
function Create-StrongPassword {										# https://powersnippets.com/create-password/
	[CmdletBinding()]Param (									# Version 01.01.00, by iRon
		[Int]$Size = 8, [Char[]]$Complexity = "ULNS", [Char[]]$Exclude
	)
	$AllTokens = @(); $Chars = @(); $TokenSets = @{
		UpperCase = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		LowerCase = [Char[]]'abcdefghijklmnopqrstuvwxyz'
		Numbers   = [Char[]]'0123456789'
		Symbols   = [Char[]]'!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
	}
	$TokenSets.Keys | Where {$Complexity -Contains $_[0]} | ForEach {
		$TokenSet = $TokenSets.$_ | Where {$Exclude -cNotContains $_} | ForEach {$_}
		If ($_[0] -cle "Z") {$Chars += $TokenSet | Get-Random}					#Character sets defined in uppercase are mandatory
		$AllTokens += $TokenSet
	}
	While ($Chars.Count -lt $Size) {$Chars += $AllTokens | Get-Random}
	($Chars | Sort-Object {Get-Random}) -Join ""								#Mix the (mandatory) characters and output string
}

Export-ModuleMember -Function Configure-Lab, Create-StrongPassword, RemoveAndClean-ClaimsProviderSolution, Generate-FeatureFileDefinition