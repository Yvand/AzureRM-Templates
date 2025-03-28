#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="7.8.0" } # min version to fix https://github.com/Azure/azure-powershell/issues/26752

param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password
)

$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateParametersFileName = 'main.bicepparam'
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force

# Create the resource group if needed
if ($null -eq (Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

Write-Host "Test if template is valid..." -ForegroundColor Green
#az deployment sub create --name $deploymentName --location $resourceGroupLocation --parameters $templateParametersFileName --parameters resourceGroupName="$resourceGroupName" adminPassword="$password" otherAccountsPassword="$password"
$testResult = Test-AzResourceGroupDeployment -Verbose -ResourceGroupName $resourceGroupName -TemplateParameterFile $templateParametersFileName `
    -adminPassword $securePassword -otherAccountsPassword $securePassword
if (![string]::IsNullOrWhiteSpace($testResult.Message)) {
    Write-Host "Template validation failed: $($testResult.Message)" -ForegroundColor Red
    $testResult
    return
}

# Template is valid, deploy it
$startTime = $(Get-Date)
Write-Host "Template is valid, starting deployment..." -ForegroundColor Green
$result = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
    -TemplateParameterFile $templateParametersFileName -Verbose `
    -adminPassword $securePassword -otherAccountsPassword $securePassword

$result
$elapsedTime = New-TimeSpan $startTime $(get-date)
if ($result.ProvisioningState -eq "Succeeded") {
    Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
    $outputs = (Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName).Outputs        
    $outputMessage = "Use the account ""$($outputs.domainAdminAccount.value)"" (""$($outputs.domainAdminAccountFormatForBastion.value)"") to sign in"
    if ($outputs.ContainsKey("publicIPAddressSP") -and ![String]::IsNullOrWhiteSpace($outputs.publicIPAddressSP.value)) {
        $outputMessage += " to ""$($outputs.publicIPAddressSP.value)"""
    }
    Write-Host $outputMessage -ForegroundColor Green
}
else {
    Write-Host "Deployment failed with status $($result.ProvisioningState) after $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Red
}
