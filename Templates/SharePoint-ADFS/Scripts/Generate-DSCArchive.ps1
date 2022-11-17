#Requires -PSEdition Desktop
#Requires -Module Az.Compute

param(
    [string] $vmName = "*",
    [string] $dscFolderName = "dsc"
)

$dscFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\$dscFolderName" -Resolve
if (Test-Path $dscFolder) {
    $dscSourceFilePaths = Get-ChildItem $dscFolder -File -Filter "Configure$vmName*.ps1"
    foreach ($dscSourceFilePath in $dscSourceFilePaths) {
        $dscArchiveFilePath = "$($dscSourceFilePath.DirectoryName)\$($dscSourceFilePath.BaseName).zip"
        Publish-AzVMDscConfiguration -ConfigurationPath ".\$dscFolderName\$($dscSourceFilePath.Name)" -OutputArchivePath $dscArchiveFilePath -Force -Verbose
    }
}
