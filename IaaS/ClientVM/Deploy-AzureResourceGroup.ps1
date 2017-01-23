### Ensure connection to Azure RM
$azurecontext = $null
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue

if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}

if ($azurecontext -eq $null){ 
    return
}


### Define variables
{
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'ydclient'
$resourceDeploymentName = "$resourceGroupName-deployment"
$templateFileName = 'azuredeploy.json'
$templateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $templateFileName))
$templateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine("C:\Job\Dev\Github\AzureRM-Templates\IaaS\ClientVM", $templateFileName))
$securePassword = Read-Host "Enter the password" -AsSecureString

$additionalParameters = New-Object -TypeName HashTable
$additionalParameters['adminPassword'] = $securePassword
$additionalParameters['templatePrefix'] = "ydclient"
}

### Create Resource Group if it doesn't exist
if ((Get-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue) -eq $null) {
    New-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
}

### Deploy Resources
$checkTemplate = Test-AzureRmResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFile `
    @additionalParameters

if ($checkTemplate.Count -eq 0) {
    New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        @additionalParameters `
        -Verbose -Force
}
else { $checkTemplate }
