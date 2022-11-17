#Requires -PSEdition Desktop
#Requires -Module Az.Compute

param(
    [string] $vmName = "*",
    [string] $dscFolderRelativePath = ".\dsc"
)

if (Test-Path $dscFolderRelativePath) {
    $dscSourceFilePaths = Get-ChildItem $dscFolderRelativePath -File -Filter "Configure$vmName*.ps1"
    foreach ($dscSourceFilePath in $dscSourceFilePaths) {
        $dscArchiveFilePath = "$($dscSourceFilePath.DirectoryName)\$($dscSourceFilePath.BaseName).zip"
        Publish-AzVMDscConfiguration -ConfigurationPath "$dscFolderRelativePath\$($dscSourceFilePath.Name)" -OutputArchivePath $dscArchiveFilePath -Force -Verbose
    }
}
