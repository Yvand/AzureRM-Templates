### Define variables
{
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'samplesite-paas'
$resourceDeploymentName = 'samplesite-paas-deployment'
$templateFileName = 'azuredeploy.json'
$templatePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $templateFileName))
}

<#
Login-AzureRmAccount
#>

### Create Resource Group
{
New-AzureRmResourceGroup `
    -Name $resourceGroupName `
    -Location $resourceGroupLocation `
    -Verbose -Force
}

### Deploy Resources
{
New-AzureRmResourceGroupDeployment `
    -Name $resourceDeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templatePath `
    -Verbose -Force
}
