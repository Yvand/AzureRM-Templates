#Requires -Module Az.Resources

### Define variables
$resourceGroupLocation = 'westeurope'
#$resourceGroupLocation = 'northeurope'
$resourceGroupName = 'ydqs1'
$resourceDeploymentName = "$resourceGroupName-deployment"
$templateFileName = 'azuredeploy.json'
$templateParametersFileName = 'azuredeploy.parameters.json'
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SharePoint-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))

Write-Host "Starting deployment of template in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green
### Set passwords
# $securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
if ($null -eq $securePassword) { $securePassword = Read-Host "Type the password of admin and service accounts" -AsSecureString }
# $passwords = New-Object -TypeName HashTable
# $passwords.adminPassword = $securePassword
# $passwords.serviceAccountsPassword = $securePassword

### Set parameters
$parameters = New-Object -TypeName HashTable
$parameters.adminPassword = $securePassword
$parameters.serviceAccountsPassword = $securePassword
$paramFileContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$paramFileContent.parameters | Get-Member -MemberType *Property | ForEach-Object { 
    $parameters.($_.name) = $paramFileContent.parameters.($_.name).value; 
}

### Ensure connection to Azure RM
$azurecontext = $null
$azurecontext = Get-AzContext -ErrorAction SilentlyContinue
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) {
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Connect-AzAccount
    $azurecontext = Get-AzContext -ErrorAction SilentlyContinue
}
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) { 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

### Create Resource Group if it doesn't exist
if ($null -eq (Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

### Test template and deploy if it is valid, otherwise display error details
$checkTemplate = Test-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $TemplateFile `
    -TemplateParameterObject $parameters `
    -Verbose
    # -TemplateParameterFile $templateParametersFile `
    # @passwords `

if ($checkTemplate.Count -eq 0) {
    # Template is valid, deploy it
    $startTime = $(Get-Date)
    Write-Host "Starting template deployment..." -ForegroundColor Green
    $result = New-AzResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterObject $parameters `
        -Verbose -Force
        # -TemplateParameterFile $templateParametersFile `
        # @passwords `

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
