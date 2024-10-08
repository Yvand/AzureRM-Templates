#Requires -PSEdition Core
#Requires -Module Az.Resources

### Set variables
$resourceGroupLocation = 'francecentral'
$resourceGroupName = "xxydsp2"
# $resourceGroupName = "gf(d)df_-sf.sm"
$templateFileName = 'main.bicep'
$templateParametersFileName = 'azuredeploy.parameters.json'

### Set passwords
# $securePassword = $password| ConvertTo-SecureString -AsPlainText -Force
if ($null -eq $securePassword) { $securePassword = Read-Host "Type the password of admin and service accounts" -AsSecureString }
$passwords = New-Object -TypeName HashTable
$passwords.adminPassword = $securePassword
$passwords.otherAccountsPassword = $securePassword

# ### Set parameters
$scriptRoot = $PSScriptRoot
#$scriptRoot = "C:\Job\Dev\Github\AzureRM-Templates\SharePoint\SharePoint-ADFS"
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateFileName))
$templateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $templateParametersFileName))
# $parameters = New-Object -TypeName HashTable
# $parameters.adminPassword = $securePassword
# $parameters.otherAccountsPassword = $securePassword
# $paramFileContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
# $paramFileContent.parameters | Get-Member -MemberType *Property | ForEach-Object { 
#     $parameters.($_.name) = $paramFileContent.parameters.($_.name).value; 
# }

Write-Host "Starting deployment of template in resource group '$resourceGroupName' in '$resourceGroupLocation'..." -ForegroundColor Green

### Validate connection to Azure
$azurecontext = $null
$azurecontext = Get-AzContext -ErrorAction SilentlyContinue
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) {
    Write-Host "Connecting to Azure..." -ForegroundColor Green
    Connect-AzAccount -UseDeviceAuthentication
    $azurecontext = Get-AzContext -ErrorAction SilentlyContinue
}
if ($null -eq $azurecontext -or $null -eq $azurecontext.Account -or $null -eq $azurecontext.Subscription) { 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

### Create the resource group if needed
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

$resourceDeploymentName = "$resourceGroupName-deployment"
if ($checkTemplate.Count -eq 0) {
    # Template is valid, deploy it
    $startTime = $(Get-Date)
    Write-Host "Starting deployment of template..." -ForegroundColor Green
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
        $outputMessage += $outputs.ContainsKey("publicIPAddressSP") ? " to ""$($outputs.publicIPAddressSP.value)""" : "."
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
