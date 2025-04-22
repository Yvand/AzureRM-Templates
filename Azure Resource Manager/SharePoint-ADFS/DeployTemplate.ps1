#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="7.8.0" } # min version to fix https://github.com/Azure/azure-powershell/issues/26752

param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password
)

$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateParametersFileName = 'main.bicepparam'
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force

Write-Host "Deploying '$deploymentName' to '$resourceGroupName' in '$resourceGroupLocation'" -ForegroundColor Green
$startTime = $(Get-Date)
#az deployment sub create --name $deploymentName --location $resourceGroupLocation --parameters $templateParametersFileName --parameters resourceGroupName="$resourceGroupName" adminPassword="$password" otherAccountsPassword="$password"
New-AzDeployment -Name $deploymentName -Location $resourceGroupLocation -TemplateParameterFile $templateParametersFileName -Verbose `
    -resourceGroupName $resourceGroupName -adminPassword $securePassword -otherAccountsPassword $securePassword
$elapsedTime = New-TimeSpan $startTime $(get-date)
Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green
