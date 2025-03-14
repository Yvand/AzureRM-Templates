#Requires -PSEdition Core
#Requires -Module Az.Resources

param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password = ""
)

# Set variables
$templateFileName = 'main.bicep'
$templateParametersFileName = 'azuredeploy.parameters.json'

# Set passwords
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force -ErrorAction SilentlyContinue
if ($null -eq $securePassword) { $securePassword = Read-Host "Type the password of admin and service accounts" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords.adminPassword = $securePassword
$passwords.otherAccountsPassword = $securePassword

# Set parameters
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\YvanData\repos\AzureRM-Templates\Azure Resource Manager\SharePoint-ADFS"
$templateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))
# $parameters = New-Object -TypeName HashTable
# $parameters.adminPassword = $securePassword
# $parameters.otherAccountsPassword = $securePassword
# $paramFileContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
# $paramFileContent.parameters | Get-Member -MemberType *Property | ForEach-Object { 
#     $parameters.($_.name) = $paramFileContent.parameters.($_.name).value; 
# }

Write-Host "Starting deployment of template in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green

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

# Create the resource group if needed
if ($null -eq (Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

# Test the template and print the errors if any
$templateErrors = Test-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFile `
    -Verbose `
    -TemplateParameterFile $templateParametersFile `
    @passwords
# -TemplateParameterObject $parameters

if ($templateErrors.Count -gt 0) {
    Write-Host "Template validation failed with $($templateErrors.Count) errors" -ForegroundColor Red
    foreach ($templateError in $templateErrors) 
    { 
        Write-Host "Error: $($templateError.Message)" -ForegroundColor Red
        $templateError.Details
    }
    return
}

# Template is valid, deploy it
$resourceDeploymentName = "deploy-template-SharePoint"
$startTime = $(Get-Date)
Write-Host "Template is valid, starting deployment..." -ForegroundColor Green
$result = New-AzResourceGroupDeployment `
    -Name $resourceDeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFile `
    -Verbose -Force `
    -TemplateParameterFile $templateParametersFile `
    @passwords 
# -TemplateParameterObject $parameters

$result
$elapsedTime = New-TimeSpan $startTime $(get-date)
if ($result.ProvisioningState -eq "Succeeded") {
    Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
    $outputs = (Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $resourceDeploymentName).Outputs        
    $outputMessage = "Use the account ""$($outputs.domainAdminAccount.value)"" (""$($outputs.domainAdminAccountFormatForBastion.value)"") to sign in"
    if ($outputs.ContainsKey("publicIPAddressSP") -and ![String]::IsNullOrWhiteSpace($outputs.publicIPAddressSP.value)) {
        $outputMessage += " to ""$($outputs.publicIPAddressSP.value)"""
    }
    Write-Host $outputMessage -ForegroundColor Green
}
else {
    Write-Host "Deployment failed with status $($result.ProvisioningState) after $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Red
}
