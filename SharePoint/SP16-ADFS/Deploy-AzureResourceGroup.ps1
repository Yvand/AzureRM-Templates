#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

### Define variables
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'yd-sp16adfs'
$resourceDeploymentName = 'yd-sp16adfs-deployment'
$templateFileName = 'azuredeploy.json'
$templateParametersFileName = 'azuredeploy.parameters.json'
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SP16-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))
$dscSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, "dsc"))

### Define passwords
#$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
if ($securePassword -eq $null) { $securePassword = Read-Host "Enter the password" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords['adminPassword'] = $securePassword
$passwords['adfsSvcPassword'] = $securePassword
$passwords['sqlSvcPassword'] = $securePassword
$passwords['spSetupPassword'] = $securePassword
$passwords['spFarmPassword'] = $securePassword
$passwords['spSvcPassword'] = $securePassword
$passwords['spAppPoolPassword'] = $securePassword
$passwords['spPassphrase'] = $securePassword

### Parse the parameters file
$JsonContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$JsonParameters = $JsonContent | Get-Member -Type NoteProperty | Where-Object {$_.Name -eq "parameters"}
if ($JsonParameters -eq $null) {
    $JsonParameters = $JsonContent
}
else {
    $JsonParameters = $JsonContent.parameters
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
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

### Generate DSC archives
$generateDscArchives = $false
if ($generateDscArchives) {
    if (Test-Path $dscSourceFolder) {
        $dscSourceFilePaths = @(Get-ChildItem $dscSourceFolder -File -Filter "*SPVM.ps1" | ForEach-Object -Process {$_.FullName})
        foreach ($dscSourceFilePath in $dscSourceFilePaths) {
            $dscArchiveFilePath = $dscSourceFilePath.Substring(0, $dscSourceFilePath.Length - 4) + ".zip"
            Publish-AzureRmVMDscConfiguration $dscSourceFilePath -OutputArchivePath $dscArchiveFilePath -Force -Verbose
        }
    }
}

### Create Resource Group if it doesn't exist
if ((Get-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue) -eq $null) {
    New-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

### Test template and deploy if it is valid, otherwise display error details
$checkTemplate = Test-AzureRmResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $TemplateFile `
    -TemplateParameterFile $templateParametersFile `
    @passwords `
    -Verbose

if ($checkTemplate.Count -eq 0) {
    # Template is valid, deploy it
    $result = New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $templateParametersFile `
        @passwords `
        -Verbose -Force

    $result
    if ($result.ProvisioningState -eq "Succeeded") {
        Write-Host "Deployment completed successfully." -ForegroundColor Green
    }

}
else {
    # Template is not valid, display errors
    $checkTemplate[0].Details
}
