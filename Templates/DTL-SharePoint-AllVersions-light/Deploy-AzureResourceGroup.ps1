#Requires -PSEdition Core
#Requires -Module Az.Resources

### Define variables
$resourceGroupLocation = 'westeurope'
$resourceGroupLocation = 'francecentral'
$resourceGroupName = 'ydtlight1'
# $resourceGroupName = 'ydtlight1gf(d)df_-sf.sm'
$templateFileName = 'azuredeploy.json'
$templateParametersFileName = 'azuredeploy.parameters.json'
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SharePoint-ADFS-DevTestLabs"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))

### Set passwords
# $securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
if ($null -eq $securePassword) { $securePassword = Read-Host "Type the password of admin and service accounts" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords.adminPassword = $securePassword
$passwords.serviceAccountsPassword = $securePassword

### Set parameters
$parameters = New-Object -TypeName HashTable
$parameters.adminPassword = $securePassword
$parameters.serviceAccountsPassword = $securePassword
$paramFileContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
$paramFileContent.parameters | Get-Member -MemberType *Property | ForEach-Object { 
    $parameters.($_.name) = $paramFileContent.parameters.($_.name).value; 
}

$resourceDeploymentName = "$resourceGroupName-deployment"
Write-Host "Starting deployment of template in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green

### Ensure connection to Azure RM
$azurecontext = $null
$azurecontext = Get-AzContext -ErrorAction SilentlyContinue
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) {
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Connect-AzAccount
    $azurecontext = Get-AzContext -ErrorAction SilentlyContinue
}
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) { 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

### Create Resource Group if it doesn't exist
if ($null -eq (Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $resourceGroupLocation `
        -Verbose -Force
    Write-Host "Created resource group $resourceGroupName." -ForegroundColor Green
}

### Test template and deploy if it is valid, otherwise display error details
$checkTemplate = Test-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $TemplateFile `
    -Verbose `
    -TemplateParameterFile $templateParametersFile `
    @passwords
    # -TemplateParameterObject $parameters

if ($checkTemplate.Count -eq 0) {
    # Template is valid, deploy it
    $startTime = $(Get-Date)
    Write-Host "Starting template deployment..." -ForegroundColor Green
    $result = New-AzResourceGroupDeployment `
        -Name $resourceDeploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $TemplateFile `
        -Verbose -Force `
        -TemplateParameterFile $templateParametersFile `
        @passwords 
        # -TemplateParameterObject $parameters

    $elapsedTime = New-TimeSpan $startTime $(get-date)
    $result
    if ($result.ProvisioningState -eq "Succeeded") {
        Write-Host "Deployment completed successfully in $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Green

        $outputs = (Get-AzResourceGroupDeployment `
            -ResourceGroupName $resourceGroupName `
            -Name $resourceDeploymentName).Outputs
        
        $outputMessage = "Use the account ""$($outputs.domainAdminAccount.value)"" (""$($outputs.domainAdminAccountFormatForBastion.value)"") to sign in"
        $outputMessage += $outputs.ContainsKey("publicIPAddressSPSE") ? " to ""$($outputs.publicIPAddressSPSE.value)""" : "."
        Write-Host $outputMessage -ForegroundColor Green
    }
    else {
        Write-Host "Deployment failed after $($elapsedTime.ToString("h\hmm\m\n"))." -ForegroundColor Red
    }
}
else {
    Write-Host "Template validation failed: $($checkTemplate[0].Message)" -ForegroundColor Red
    $checkTemplate[0].Details
    $checkTemplate[0].Details.Details
}
