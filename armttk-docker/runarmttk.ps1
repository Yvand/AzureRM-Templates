Import-Module /src/arm-ttk/arm-ttk/arm-ttk.psd1

#$testsResults = Test-AzTemplate -TemplatePath /src/AzureRM-Templates/Templates/SharePoint-ADFS
$testsResults = $null
$directories = Get-ChildItem -Path "/src/AzureRM-Templates/Templates" -Recurse -Filter "azuredeploy.parameters.json" | %{[System.IO.Path]::GetDirectoryName($_)}
foreach ($directory in $directories) {
	$testsResults += Test-AzTemplate -TemplatePath $directory
}

$testsErrors =  $testsResults | Where-Object {$false -eq $_.Passed}

if ($null -eq $testsErrors) {
	Write-Host "All tests passed"
    exit 0
} 
else {
	Write-Host "The following files did not pass the Azure Resource Manager Template Toolkit tests:"
    $testsErrors.File.FullPath | Select-Object -Unique
    Write-Host "Detailed errors:"
    Write-Output $testsErrors
    exit 1    
}