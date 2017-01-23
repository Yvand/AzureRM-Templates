### Ensure connection to Azure RM
$azurecontext = $null
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue

if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
    <#
    Get-AzureRmSubscription
    Select-AzureRmSubscription -SubscriptionId 00000-0000-0000-000-0000
    #>
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
$errorMessages = @()
    $errorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        @additionalParameters `
        -verbose)

if ($errorMessages -eq $null) {
    New-AzureRmResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        @additionalParameters `
        -Verbose -Force `
        -ErrorVariable $errorMessages
}

if ($errorMessages)
{
    "", ("{0} returned the following errors:" -f ("Template deployment", "Validation")[[bool]$ValidateOnly]), @($errorMessages) | ForEach-Object { Write-Output $_ }
}

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @("  " * $Depth + $_.Code + ": " + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}
