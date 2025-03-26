param(
    [string] $resourceGroupLocation = "francecentral",
    [string] $resourceGroupName,
    [string] $password
)

$deploymentName = "sharepoint-{0:yyMMdd-HHmm}" -f (Get-Date)
$templateParametersFileName = 'main.bicepparam'

Write-Host "Deploying '$deploymentName' to '$resourceGroupName' in '$resourceGroupLocation'"
az deployment sub create --name $deploymentName --location $resourceGroupLocation --parameters $templateParametersFileName --parameters resourceGroupName="$resourceGroupName" adminPassword="$password" otherAccountsPassword="$password"
