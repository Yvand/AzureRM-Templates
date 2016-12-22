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
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $templateFileName))
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine("C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SP16-ADFS", $templateFileName))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))
#$password = "****"
#$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
$securePassword = Read-Host "Enter the password" -AsSecureString

$DSCSourceFolder = 'DSC'
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

if ($UploadArtifacts) {
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine("C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SP16-ADFS", $DSCSourceFolder))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter "*.ps1" | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + ".zip"
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }
}

### Create Resource Group if it doesn't exist
if ((Get-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue) -eq $null) {
    New-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
}

### Deploy template
$additionalParameters = New-Object -TypeName HashTable
$additionalParameters['adminPassword'] = $securePassword
$additionalParameters['sqlSvcPassword'] = $securePassword
$additionalParameters['spSetupPassword'] = $securePassword
New-AzureRmResourceGroupDeployment `
    -Name $resourceDeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $TemplateFile `
    @additionalParameters `
    -Verbose -Force

### Remove initial extension on SQL VM and add new one
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