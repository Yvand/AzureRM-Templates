Import-Module "${Env:ARMTTK_PATH}/arm-ttk/arm-ttk.psd1"

$testResults = $null
#$testResults = Test-AzTemplate -TemplatePath "/github/workspace/Templates/SharePoint-ADFS"
$directories = Get-ChildItem -Path "/github/workspace/Templates" -Recurse -Filter "azuredeploy.parameters.json" | %{[System.IO.Path]::GetDirectoryName($_)}
foreach ($directory in $directories) {
	# Skip test artifacts-parameter - https://github.com/Azure/arm-ttk/issues/637
    $testResults += Test-AzTemplate -TemplatePath $directory -Skip "artifacts-parameter" #-TestParameter @{RawRepoPath="https://github.com/Yvand/AzureRM-Templates/raw/master/Templates/"}
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