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
$resourceGroupName = 'yd-multiplespvms'
$resourceDeploymentName = 'yd-multiplespvms-deployment'
$templateFileName = 'azuredeploy.json'
$templatePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $templateFileName))
$templatePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine("C:\Job\Dev\Github\AzureRM-Templates\IaaS\MultipleSPVMs", $templateFileName))
$password = "Passdemerde!"
$securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
}

### Create Resource Group
{
New-AzureRmResourceGroup `
    -Name $resourceGroupName `
    -Location $resourceGroupLocation `
    -Verbose -Force
}

### Deploy Resources
{
$additionalParameters = New-Object -TypeName HashTable
$additionalParameters['adminPassword'] = $securePassword

New-AzureRmResourceGroupDeployment `
    -Name $resourceDeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templatePath `
    @additionalParameters `
    -Verbose -Force
}
