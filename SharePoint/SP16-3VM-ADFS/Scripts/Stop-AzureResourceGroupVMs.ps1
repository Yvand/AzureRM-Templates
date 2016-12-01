#Requires -Version 3.0

Param(
  [string] [ValidateSet('SPPLA_ARM_Test', 'SQLAOTest')] [Parameter(Mandatory=$true)] $ResourceGroupName
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

Write-Output -InputObject "*******************************************************************"
Write-Output -InputObject " Shutting down SharePoint Resource Group VMs in $ResourceGroupName"
Write-Output -InputObject "*******************************************************************"

Write-Output -InputObject "Task 1: Shutting down VMs"    
Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Stop-AzureRmVM -Force -Verbose

Write-Output -InputObject "All VMs are now deallocated"    
