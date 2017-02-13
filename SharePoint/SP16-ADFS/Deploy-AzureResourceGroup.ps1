#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

### Define variables
{
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'yd-sp16adfs'
$resourceDeploymentName = 'yd-sp16adfs-deployment'
$templateFileName = 'azuredeploy.json'
$TemplateParametersFile = 'azuredeploy.parameters.json'
$DSCSourceFolder = 'DSC'
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SP16-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $TemplateParametersFile))
$optionalParameters = New-Object -TypeName HashTable

# Define passwords
#$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
$securePassword = Read-Host "Enter the password" -AsSecureString
$passwords = New-Object -TypeName HashTable
$passwords['adminPassword'] = $securePassword
$passwords['adfsSvcPassword'] = $securePassword
$passwords['sqlSvcPassword'] = $securePassword
$passwords['spSetupPassword'] = $securePassword
$passwords['spFarmPassword'] = $securePassword
$passwords['spSvcPassword'] = $securePassword
$passwords['spAppPoolPassword'] = $securePassword
$passwords['spPassphrase'] = $securePassword

# dev branch settings
$optionalParameters['baseurl'] = "https://github.com/Yvand/AzureRM-Templates/raw/dev/SharePoint/SP16-ADFS"
$optionalParameters['baseurl'] = "https://raw.githubusercontent.com/Yvand/AzureRM-Templates/Dev/SharePoint/SP16-ADFS"
$optionalParameters['vaultName'] = "ydsp16adfsvault"
$optionalParameters['dscDCTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureDCVM.zip"
$optionalParameters['dscSQLTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureSQLVM.zip"
$optionalParameters['dscSPTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureSPVM.zip"

# Artifacts
$StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts'
$ArtifactStagingDirectory = "Artifacts"
}

### Ensure connection to Azure RM
Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = $null
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null){ 
    return
}

$GenerateDscArchives = $false
$UploadArtifacts = $false

if ($GenerateDscArchives) {
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $DSCSourceFolder))

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter "*SQLVM.ps1" | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + ".zip"
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }
}

if ($UploadArtifacts) {
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $ArtifactStagingDirectory))

	Set-Variable ArtifactsLocationName '_artifactsLocation' -Option ReadOnly -Force
    Set-Variable ArtifactsLocationSasTokenName '_artifactsLocationSasToken' -Option ReadOnly -Force

    $optionalParameters.Add($ArtifactsLocationName, $null)
    $optionalParameters.Add($ArtifactsLocationSasTokenName, $null)

	# Create a storage account name if none was provided
    if($StorageAccountName -eq "") {
        $subscriptionId = ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
        $StorageAccountName = "stage$subscriptionId"
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if($StorageAccount -eq $null){
        $StorageResourceGroupName = "ARM_Deploy_Staging"
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }

    $StorageAccountContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName}).Context

    # Generate the value for artifacts location if it is not provided in the parameter file
    $ArtifactsLocation = $optionalParameters[$ArtifactsLocationName]
    if ($ArtifactsLocation -eq $null) {
        $ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName
        $optionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccountContext -Permission Container -ErrorAction SilentlyContinue *>&1

	$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force -ErrorAction Stop
    }

    # Generate the value for artifacts location SAS token if it is not provided in the parameter file
    $ArtifactsLocationSasToken = $optionalParameters[$ArtifactsLocationSasTokenName]
    if ($ArtifactsLocationSasToken -eq $null) {
        # Create a SAS token for the storage container - this gives temporary read-only access to the container
        $ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(4)
        $ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
        $optionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ArtifactsLocationSasToken)
        $UnsecureSASToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $UnsecureSASToken
        ConvertFrom-SecureString $ArtifactsLocationSasToken
    }
}

### Configure Azure key vault
$vault = Get-AzureRmKeyVault -VaultName $optionalParameters['vaultName']
if ($vault -eq $null) {
    $vault = New-AzureRmKeyVault -VaultName $optionalParameters['vaultName'] -ResourceGroupName $resourceGroupName -Location $resourceGroupLocation -EnabledForTemplateDeployment
    $vault.ResourceId
}

# Create one key per password and overrride password with the key vault secret
$vaultSecrets = New-Object -TypeName HashTable
foreach ($password in $passwords.GetEnumerator()) {
    $secret = Set-AzureKeyVaultSecret -VaultName $optionalParameters['vaultName'] -Name $password.Name -SecretValue $password.Value
    $key = $secret.Name + "KeyName"
    $vaultSecrets[$key] = $secret.Name
}

### Create Resource Group if it doesn't exist
if ((Get-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue) -eq $null) {
    New-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
}

### Deploy template if it is valid
$checkTemplate = Test-AzureRmResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $TemplateFile `
    @optionalParameters `
    @vaultSecrets `
    -Verbose

if ($checkTemplate.Count -eq 0) {
    New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        @optionalParameters `
        @vaultSecrets `
        -Verbose -Force
}

### Remove initial extension on a VM and add a new one
{
$SQLVMname = "SQL"
$previousCustomExtension = "PrepareSQLVM"
$newCustomExtension = "ConfigureSQLVM"
Remove-AzurermVMCustomScriptExtension -ResourceGroupName $resourceGroupName `
    -VMName $SQLVMname –Name $previousCustomExtension -Force

Set-AzureRMVMExtension –ResourceGroupName $resourceGroupName -Location $resourceGroupLocation `
    -extensiontype "DSC" -name $newCustomExtension -Publisher "Microsoft.Powershell" `
    -TypeHandlerVersion "2.9" -VMName $SQLVMname `
    -Settings @{"workspaceId" = "WorkspaceID"} -ProtectedSettings @{"workspaceKey"= "workspaceID"}
}

### Shutdown VMs
{
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP" -Force
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL" -Force
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC" -Force
}

### Start VMs
{
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "DC"
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SQL"
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name "SP"
}