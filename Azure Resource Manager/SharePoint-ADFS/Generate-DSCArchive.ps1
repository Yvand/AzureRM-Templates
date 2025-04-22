#Requires -PSEdition Desktop
#Requires -Module Az.Compute

# Get-Command -Verb Publish -Noun AzVM* -Module Az.Compute

param(
    [string] $vmName = "*",
    [string] $dscFolderPath = ".\dsc"
)

if (Test-Path $dscFolderPath) {
    Write-Host "Generating DSC archives in folder '$dscFolderPath' for VMs '$vmName'" -ForegroundColor Cyan
    $dscSourceFilePaths = Get-ChildItem $dscFolderPath -File -Filter "Configure$vmName*.ps1"
    foreach ($dscSourceFilePath in $dscSourceFilePaths) {
        $dscArchiveFilePath = "$($dscSourceFilePath.DirectoryName)\$($dscSourceFilePath.BaseName).zip"
        Publish-AzVMDscConfiguration -ConfigurationPath "$dscFolderPath\$($dscSourceFilePath.Name)" -OutputArchivePath $dscArchiveFilePath -Force -Verbose
    }
}
else {  
    Write-Host "folder '$dscFolderPath' not found" -ForegroundColor Red
}