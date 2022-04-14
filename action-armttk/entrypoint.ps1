Import-Module "${Env:ARMTTK_PATH}/arm-ttk/arm-ttk.psd1"

# Remove arm-ttk test that causes an error for DevTest Labs templates, because they cannot use deployment().properties.templateLink.uri - https://github.com/Azure/azure-devtestlab/issues/833
Remove-Item -Path "${Env:ARMTTK_PATH}/arm-ttk/testcases/deploymentTemplate/artifacts-parameter.test.ps1" -Confirm:$false

$testResults = $null
#$testResults = Test-AzTemplate -TemplatePath "/github/workspace/Templates/SharePoint-ADFS"
$directories = Get-ChildItem -Path "/github/workspace/Templates" -Recurse -Filter "azuredeploy.parameters.json" | %{[System.IO.Path]::GetDirectoryName($_)}
foreach ($directory in $directories) {
	$testResults += Test-AzTemplate -TemplatePath $directory
}

$testErrors =  $testResults | Where-Object {$false -eq $_.Passed}
if ($null -eq $testErrors) {
	Write-Host "All tests passed"
    exit 0
} 
else {
	Write-Host "The following files did not pass the Azure Resource Manager Template Toolkit tests:"
    $testErrors.File.FullPath | Select-Object -Unique
    Write-Host "Errors:"
    Write-Output $testErrors
    exit 1    
}