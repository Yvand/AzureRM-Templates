#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="7.8.0" } # min version to fix https://github.com/Azure/azure-powershell/issues/26752

param(
    [string] $resourceGroupLocation = "france central",
    [string] $resourceGroupName,
    [string] $password
)

$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateParametersFileName = 'main.bicepparam'
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force

# Create the resource group if needed
if ($null -eq (Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

Write-Host "Deploying '$deploymentName' to '$resourceGroupName' in '$resourceGroupLocation'" -ForegroundColor Green
$startTime = $(Get-Date)
# az deployment group create --name $deploymentName --resource-group $resourceGroupName --parameters $templateParametersFileName --parameters adminPassword="$password" otherAccountsPassword="$password"
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateParameterFile $templateParametersFileName -Verbose `
    -adminPassword $securePassword -otherAccountsPassword $securePassword
$elapsedTime = New-TimeSpan $startTime $(get-date)
Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
