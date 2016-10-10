#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'SPPLA_Arm_Test',
    [string] $VaultName = "plavault"
)

New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -EnabledForTemplateDeployment