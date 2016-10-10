#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'SPPLA_Arm_Test',
    [string] $VaultName = "plavault",
    [string] $SecretKey = "spsetup",
    [string] $SecretValue = "pass@word1"
)

$vault = Get-AzureRmKeyVault -VaultName $VaultName
$pass = ConvertTo-SecureString $SecretValue -AsPlainText -Force

if ($vault -ne $null)
{
    $secret = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretKey -SecretValue $pass
}