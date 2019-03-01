<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation
From https://blogs.msdn.microsoft.com/devtestlab/2017/12/07/using-powershell-to-deploy-devtest-lab-artifacts/
 
.SYNOPSIS
This script creates a new environment in the lab using an existing environment template.
 
.PARAMETER DevTestLabName
   The name of the lab.
.PARAMETER VirtualMachineName
   The virtual machine name to deploy to
.PARAMETER RepositoryName
   The name of the repository in the lab.
.PARAMETER ArtifactName
   The name of the artifact to be deployed
.PARAMETER Params
   The parameters pairs to be passed into the artifact ie params_TestVMAdminUserName = adminuser params_TestVMAdminPassword = pwd
 
.NOTES
The script assumes that a lab exists, has a repository connected, and the artifact is in the repository.
#>
 
#Requires -Version 3.0
#Requires -Module AzureRM.Resources
 
param
(
[Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab containing the Virtual Machine")]
   [string] $DevTestLabName,
[Parameter(Mandatory=$true, HelpMessage="The name of the Virtual Machine")]
   [string] $VirtualMachineName,
[Parameter(Mandatory=$true, HelpMessage="The repository where the artifact is stored")]
   [string] $RepositoryName,
[Parameter(Mandatory=$true, HelpMessage="The artifact to apply to the virtual machine")]
   [string] $ArtifactName,
[Parameter(ValueFromRemainingArguments=$true)]
   $Params
)

<#
Connect-AzureRmAccount
$SubscriptionId = "XXX"
Set-AzureRmContext -SubscriptionId $SubscriptionId | Out-Null
#>

# Set the appropriate subscription
$SubscriptionId = (Get-AzureRmSubscription | Select-Object -First 1).SubscriptionId
  
# Get the lab resource group name
Write-Output "Getting lab resource name using subscription ID $SubscriptionId..."
$resourceGroupName = (Get-AzureRmResource -ResourceId "/subscriptions/$SubscriptionId/providers/Microsoft.DevTestLab/labs" | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
if ($resourceGroupName -eq $null) { throw "Unable to find lab $DevTestLabName in subscription $SubscriptionId." }
 
# Get the internal repo name
Write-Output  "Getting repository in lab $DevTestLabName in resource group $resourceGroupName..."
$repository = Get-AzureRmResource -ResourceGroupName $resourceGroupName `
-ResourceType 'Microsoft.DevTestLab/labs/artifactsources' `
-ResourceName $DevTestLabName `
-ApiVersion 2016-05-15 `
| Where-Object { $RepositoryName -in ($_.Name, $_.Properties.displayName) } `
| Select-Object -First 1
 
if ($repository -eq $null) { "Unable to find repository $RepositoryName in lab $DevTestLabName." }
 
# Get the internal artifact name
Write-Output "Getting artifact $ArtifactName in repository $($repository.Name)..."
$template = Get-AzureRmResource -ResourceGroupName $resourceGroupName `
-ResourceType "Microsoft.DevTestLab/labs/artifactSources/artifacts" `
-ResourceName "$DevTestLabName/$($repository.Name)" `
-ApiVersion 2016-05-15 `
| Where-Object { $ArtifactName -in ($_.Name, $_.Properties.title) } `
| Select-Object -First 1
 
if ($template -eq $null) { throw "Unable to find template $ArtifactName in lab $DevTestLabName." }
 
# Find the virtual machine in Azure
$FullVMId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/virtualmachines/$virtualMachineName"

Write-Output "Getting virtual machine $virtualMachineName..."
$virtualMachine = Get-AzureRmResource -ResourceId $FullVMId
 
# Generate the artifact id
$FullArtifactId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/artifactSources/$($repository.Name)/artifacts/$($template.Name)"
 
# Handle the inputted parameters to pass through
$artifactParameters = @()
 
# Fill artifact parameter with the additional -param_ data and strip off the -param_
$Params | ForEach-Object {
	Write-Output "Adding param $_..."
   if ($_ -match '^-param_(.*)') {
      #$name = $_.TrimStart('^-param_')
      $name = $_.Replace('-param_','')
   } elseif ( $name ) {
      if ($name -eq "scriptArguments") {
         $escapedQuotes = $_.Replace("'", "``'") + "'"
      } else {
         $escapedQuotes = $_
      }
      $artifactParameters += @{ "name" = "$name"; "value" = "$escapedQuotes" }
      $name = $null #reset name variable
   }
}
# Create structure for the artifact data to be passed to the action
 
$prop = @{
artifacts = @(
@{
artifactId = $FullArtifactId
parameters = $artifactParameters
}
)
}
# Check the VM
if ($virtualMachine -ne $null) {
   # Apply the artifact by name to the virtual machine
   Write-Output "Deploying artifact '$ArtifactName' to VM '$($virtualMachine.Name)'..."
   foreach ($propItem in $artifactParameters) {
		Write-Output "Param $($propItem.Name) has value $($propItem.Value)"
   }
   $status = Invoke-AzureRmResourceAction -Parameters $prop -ResourceId $virtualMachine.ResourceId -Action "applyArtifacts" -ApiVersion 2016-05-15 -Force
   if ($status.Status -eq 'Succeeded') {
      Write-Output "##[section] Successfully applied artifact: $ArtifactName to $VirtualMachineName"
   } else {
      Write-Error "##[error]Failed to apply artifact: $ArtifactName to $VirtualMachineName"
   }
} else {
   Write-Error "##[error]$VirtualMachine was not found in the DevTest Lab, unable to apply the artifact"
}
