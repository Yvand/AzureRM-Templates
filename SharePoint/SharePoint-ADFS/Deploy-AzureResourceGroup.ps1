#Requires -Version 3.0
#Requires -Module AzureRM.Resources

### Define variables
$resourceGroupLocation = 'westeurope'
#$resourceGroupLocation = 'northeurope'
$resourceGroupName = 'ydspadfs'
$resourceDeploymentName = "$resourceGroupName-deployment"
$templateFileName = 'azuredeploy.json'
$templateParametersFileName = 'azuredeploy.parameters.json'
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SharePoint-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))

Write-Host "Starting deployment of template in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green
### Define passwords
#$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
if ($securePassword -eq $null) { $securePassword = Read-Host "Type the password of admin and service accounts:" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords['adminPassword'] = $securePassword
$passwords['serviceAccountsPassword'] = $securePassword

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
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null) {
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
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
    $startTime = $(Get-Date)
    Write-Host "Starting template deployment..." -ForegroundColor Green
    $result = New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $templateParametersFile `
        @passwords `
        -Verbose -Force

    $elapsedTime = New-TimeSpan $startTime $(get-date)
    $result
    if ($result.ProvisioningState -eq "Succeeded") {
        Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
    }
    else {
        Write-Host "Deployment failed after $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Red
    }
}
else {
    Write-Host "Template validation failed: $($checkTemplate[0].Message)" -ForegroundColor Red
    $checkTemplate[0].Details
    $checkTemplate[0].Details.Details
}
