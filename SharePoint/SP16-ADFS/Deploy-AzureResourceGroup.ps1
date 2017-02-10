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
$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SP16-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $TemplateParametersFile))

#$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
$securePassword = Read-Host "Enter the password" -AsSecureString
$OptionalParameters = New-Object -TypeName HashTable
$OptionalParameters['adminPassword'] = $securePassword
$OptionalParameters['adfsSvcPassword'] = $securePassword
$OptionalParameters['sqlSvcPassword'] = $securePassword
$OptionalParameters['spSetupPassword'] = $securePassword
$OptionalParameters['spFarmPassword'] = $securePassword
$OptionalParameters['spSvcPassword'] = $securePassword
$OptionalParameters['spAppPoolPassword'] = $securePassword
$OptionalParameters['spPassphrase'] = $securePassword

# dev branch settings
$OptionalParameters['baseurl'] = "https://raw.githubusercontent.com/Yvand/AzureRM-Templates/Dev/SharePoint/SP16-ADFS"
$OptionalParameters['vaultName'] = "ydsp16adfsvault"
$OptionalParameters['dscDCTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureDCVM.zip"
$OptionalParameters['dscSQLTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureSQLVM.zip"
$OptionalParameters['dscSPTemplateURL'] = "https://github.com/Yvand/AzureRM-Templates/raw/Dev/SharePoint/SP16-ADFS/DSC/ConfigureSPVM.zip"

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

    $OptionalParameters.Add($ArtifactsLocationName, $null)
    $OptionalParameters.Add($ArtifactsLocationSasTokenName, $null)

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
    $ArtifactsLocation = $OptionalParameters[$ArtifactsLocationName]
    if ($ArtifactsLocation -eq $null) {
        $ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName
        $OptionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccountContext -Permission Container -ErrorAction SilentlyContinue *>&1

	$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force -ErrorAction Stop
    }

    # Generate the value for artifacts location SAS token if it is not provided in the parameter file
    $ArtifactsLocationSasToken = $OptionalParameters[$ArtifactsLocationSasTokenName]
    if ($ArtifactsLocationSasToken -eq $null) {
        # Create a SAS token for the storage container - this gives temporary read-only access to the container
        $ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(4)
        $ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
        $OptionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ArtifactsLocationSasToken)
        $UnsecureSASToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $UnsecureSASToken
        ConvertFrom-SecureString $ArtifactsLocationSasToken
    }
}

### Configure Azure key vault
$vault = Get-AzureRmKeyVault -VaultName $OptionalParameters['vaultName']
if ($vault -eq $null) {
    $vault = New-AzureRmKeyVault -VaultName $OptionalParameters['vaultName'] -ResourceGroupName $resourceGroupName -Location $resourceGroupLocation -EnabledForTemplateDeployment
    $vault.ResourceId
}

# Create one key per password and overrride password with the key vault secret
$passwordsHT = $OptionalParameters.GetEnumerator()| ?{$_.Name -like "*Password"}
foreach ($password in $passwordsHT) {
    $secret = Set-AzureKeyVaultSecret -VaultName $OptionalParameters['vaultName'] -Name $password.Name -SecretValue $password.Value
    $key = $secret.Name + "KeyName"
    $OptionalParameters[$key] = $secret.Name
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
    @OptionalParameters `
    -Verbose

if ($checkTemplate.Count -eq 0) {
    New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        @OptionalParameters `
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