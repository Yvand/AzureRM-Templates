#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] $ResourceGroupLocation = 'West Europe',
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName = 'SPPLA_Arm_Test',
    [switch] $UploadArtifacts = $true,
    [switch] $GenerateDSC = $false,
    [string] [Parameter(Mandatory=$true)] $ArtefactStorageAccountName = 'plaarmdiag',
    [string] $ArtefactStorageContainerName = 'stageartifacts',
    [string] $TemplateFolder = '..\Templates',
    [string] $TemplateFile = '..\Templates\azuredeploy.json',
    [string] $TemplateParametersFile = '..\Templates\azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '..\bin\Debug\staging',
    [string] $DSCSourceFolder = '..\DSC',
    [string] $DSCConfigurationFolder = '..\DSCConfiguration'

)

Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.9")
} catch { }

Set-StrictMode -Version 3

#Ensure we are logged into Azure RM
$azurecontext = $null
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue

if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}

if ($azurecontext -eq $null){ 
    return
}

$OptionalParameters = New-Object -TypeName Hashtable

# Convert relative paths to absolute paths if needed
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFolder))
$DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))
$DSCConfigurationFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCConfigurationFolder))
$ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))

if ($GenerateDSC) {
        
    $DSCConfigurationPaths = Get-ChildItem $DSCConfigurationFolder -Recurse -File | ForEach-Object -Process {$_.FullName}

    foreach ($DSCFilePath in $DSCConfigurationPaths) {
        $dscFileName = $DSCFilePath.Substring($DSCConfigurationFolder.length + 1)
        $dscOutputFilePath = $DSCSourceFolder + "\" + $dscFileName + ".zip"
        Write-Host $dscOutputFilePath
        Publish-AzureRmVMDscConfiguration -ConfigurationPath $DSCFilePath -OutputArchivePath $dscOutputFilePath -Force
    }

}

if ($UploadArtifacts) {

    Set-Variable ArtifactsLocationName 'baseUrl' -Option ReadOnly -Force
    Set-Variable ArtifactsLocationSasTokenName 'baseUrlSASToken' -Option ReadOnly -Force

    $OptionalParameters.Add($ArtifactsLocationName, $null)
    $OptionalParameters.Add($ArtifactsLocationSasTokenName, $null)

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    $JsonParameters = $JsonContent | Get-Member -Type NoteProperty | Where-Object {$_.Name -eq "parameters"}

    if ($JsonParameters -eq $null) {
        $JsonParameters = $JsonContent
    }
    else {
        $JsonParameters = $JsonContent.parameters
    }

    $JsonParameters | Get-Member -Type NoteProperty | ForEach-Object {
        $ParameterValue = $JsonParameters | Select-Object -ExpandProperty $_.Name

        if ($_.Name -eq $ArtifactsLocationName -or $_.Name -eq $ArtifactsLocationSasTokenName) {
            $OptionalParameters[$_.Name] = $ParameterValue.value
        }
    }

    # Create DSC configuration archive - DSC Already Zipped, not required
    #if (Test-Path $DSCSourceFolder) {
    #    Add-Type -Assembly System.IO.Compression.FileSystem
    #    $ArchiveFile = Join-Path $ArtifactStagingDirectory "dsc.zip"
    #    Remove-Item -Path $ArchiveFile -ErrorAction SilentlyContinue
    #    [System.IO.Compression.ZipFile]::CreateFromDirectory($DSCSourceFolder, $ArchiveFile)
    #}

    $StorageAccountContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $ArtefactStorageAccountName}).Context

    # Generate the value for artifacts location if it is not provided in the parameter file
    $ArtifactsLocation = $OptionalParameters[$ArtifactsLocationName]
    if ($ArtifactsLocation -eq $null) {
        $ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $ArtefactStorageContainerName
        $OptionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $ArtefactStorageContainerName -Context $StorageAccountContext -Permission Container -ErrorAction SilentlyContinue *>&1

    #Not copying the Staging Directory
    #$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    #foreach ($SourcePath in $ArtifactFilePaths) {
    #    $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
    #    Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force
    #}

    #Copy the DSC folder to the container
    $DscArchiveFilePaths = Get-ChildItem $DSCSourceFolder -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $DscArchiveFilePaths) {
        $BlobName = $SourcePath.Substring($DSCSourceFolder.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $ArtefactStorageContainerName -Context $StorageAccountContext -Force
    }

    #Copy the ARM JSON files to the container
    $JsonFilePaths = Get-ChildItem $TemplateFolder -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $JsonFilePaths) {
        $BlobName = $SourcePath.Substring($TemplateFolder.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $ArtefactStorageContainerName -Context $StorageAccountContext -Force
    }

    # Generate the value for artifacts location SAS token if it is not provided in the parameter file
    $ArtifactsLocationSasToken = $OptionalParameters[$ArtifactsLocationSasTokenName]
    if ($ArtifactsLocationSasToken -eq $null) {
        # Create a SAS token for the storage container - this gives temporary read-only access to the container
        $ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $ArtefactStorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(4)
        Write-Host $ArtifactsLocationSasToken
        $ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
        $OptionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken
    }
    
    Write-Host $OptionalParameters[$ArtifactsLocationSasTokenName]
    Write-Host $OptionalParameters[$ArtifactsLocationName]
}

# Create or update the resource group using the specified template file and template parameters file
#New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop 

New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParametersFile `
                                   @OptionalParameters `
                                   -Force -Verbose