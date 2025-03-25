#Requires -PSEdition Core
#Requires -Module Az.Resources

param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password
)

# Set variables
$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateFileName = 'main.bicep'
$templateParametersFileName = 'azuredeploy.parameters.jsonc'

# Set passwords
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
if ($null -eq $securePassword) { $securePassword = Read-Host "Type the password of admin and service accounts" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords.adminPassword = $securePassword
$passwords.otherAccountsPassword = $securePassword

# Set parameters
$scriptRoot = $PSScriptRoot
$templateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))
$parameters = New-Object -TypeName HashTable
# $parameters.adminPassword = $securePassword
# $parameters.otherAccountsPassword = $securePassword
$parameters.resourceGroupName = $resourceGroupName
$paramFileContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$paramFileContent.parameters | Get-Member -MemberType *Property | ForEach-Object { 
    $parameters.($_.name) = $paramFileContent.parameters.($_.name).value; 
}

# Validate connection to Azure
$azurecontext = $null
$azurecontext = Get-AzContext -ErrorAction SilentlyContinue
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) {
    Write-Host "Connecting to Azure..." -ForegroundColor Green
    Connect-AzAccount -UseDeviceAuthentication
    $azurecontext = Get-AzContext -ErrorAction SilentlyContinue
}
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) { 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

Write-Host "Validating template..." -ForegroundColor Green
$templateErrors = Test-AzDeployment -Name $deploymentName -Location $resourceGroupLocation `
    -TemplateFile $templateFile `
    -TemplateParameterObject $parameters @passwords
# -TemplateParameterFile $templateParametersFile `
# -resourceGroupName $resourceGroupName `
# -adminPassword $securePassword -otherAccountsPassword $securePassword

if ($templateErrors.Count -gt 0) {
    Write-Host "Template validation failed with $($templateErrors.Count) errors" -ForegroundColor Red
    foreach ($templateError in $templateErrors) { 
        Write-Host "Error: $($templateError.Message)" -ForegroundColor Red
        $templateError.Details
    }
    return
}

Write-Host "Validation passed, starting deployment '$deploymentName' in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green
$startTime = $(Get-Date)
$result = New-AzDeployment -Name $deploymentName -Location $resourceGroupLocation `
    -TemplateFile $templateFile `
    -TemplateParameterObject $parameters @passwords

$result
$elapsedTime = New-TimeSpan $startTime $(get-date)
if ($result.ProvisioningState -eq "Succeeded") {
    Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
}
else {
    Write-Host "Deployment failed with status $($result.ProvisioningState) after $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Red
}
