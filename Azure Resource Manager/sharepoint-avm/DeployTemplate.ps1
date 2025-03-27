#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="7.8.0" } # min version to fix https://github.com/Azure/azure-powershell/issues/26752

param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password
)

$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateParametersFileName = 'main.bicepparam'
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force

Write-Host "Deploying '$deploymentName' to '$resourceGroupName' in '$resourceGroupLocation'"
#az deployment sub create --name $deploymentName --location $resourceGroupLocation --parameters $templateParametersFileName --parameters resourceGroupName="$resourceGroupName" adminPassword="$password" otherAccountsPassword="$password"
New-AzDeployment -Name $deploymentName -Location $resourceGroupLocation -TemplateParameterFile $templateParametersFileName `
    -resourceGroupName $resourceGroupName -adminPassword $securePassword -otherAccountsPassword $securePassword
