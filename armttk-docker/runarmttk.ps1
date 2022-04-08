Import-Module /src/arm-ttk/arm-ttk/arm-ttk.psd1
# Get-ChildItem -Path "C:\Dev\Projets\AzureRM-Templates\Templates" -Recurse *.json | Test-AzTemplate
$testResults = Test-AzTemplate -TemplatePath /src/AzureRM-Templates/Templates/
$testFailures =  $testResults | Where-Object {$false -eq $_.Passed}

# If files are returning invalid configurations
# Using exit code "1" to let Github actions node the test failed
if ($null -eq $testFailures) {
	Write-Host "All tests passed"
    exit 0
} 
else {
	Write-Host "Template did not pass the following tests:"
    $testFailures.file.name | select-object -unique
    Write-Host "Results:"
    Write-Output $testFailures
    exit 1    
}