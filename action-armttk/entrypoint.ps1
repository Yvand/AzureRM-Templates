Import-Module "${Env:ARMTTK_PATH}/arm-ttk/arm-ttk.psd1"

$testResults = $null
#$testResults = Test-AzTemplate -TemplatePath "${Env:REPO_PATH}/Templates/SharePoint-ADFS"
$directories = Get-ChildItem -Path "${Env:REPO_PATH}/Templates" -Recurse -Filter "azuredeploy.parameters.json" | %{[System.IO.Path]::GetDirectoryName($_)}
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