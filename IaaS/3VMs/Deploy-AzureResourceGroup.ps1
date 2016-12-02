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
$resourceGroupName = 'samplesite-paas'
$resourceDeploymentName = 'samplesite-paas-deployment'
$templateFileName = 'azuredeploy.json'
$templatePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $templateFileName))
$templatePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine("C:\Job\Dev\Github\AzureRM-Templates\PaaS\SampleWebSite", $templateFileName))
$password = "Passdemerde!"
$securePassword = $password| ConvertTo-SecureString -AsPlainText
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
$additionalParameters['paramSecurePasswordName'] = $securePassword

New-AzureRmResourceGroupDeployment `
    -Name $resourceDeploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templatePath `
    @additionalParameters `
    -Verbose -Force
}
