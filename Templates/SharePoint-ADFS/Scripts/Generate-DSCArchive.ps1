#Requires -PSEdition Desktop
#Requires -Module Az.Compute

param(
    [string]$vmName = "*"
)

function Generate-DSCArchive($vmName) {
    $dscSourceFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\dsc" -Resolve

    if (Test-Path $dscSourceFolder) {
        $dscSourceFilePaths = Get-ChildItem $dscSourceFolder -File -Filter "Configure$vmName*.ps1"
        foreach ($dscSourceFilePath in $dscSourceFilePaths) {
            $dscArchiveFilePath = "$($dscSourceFilePath.DirectoryName)\$($dscSourceFilePath.BaseName).zip"
            Publish-AzVMDscConfiguration -ConfigurationPath ".\dsc\$($dscSourceFilePath.Name)" -OutputArchivePath $dscArchiveFilePath -Force -Verbose
        }
    }
}

Generate-DSCArchive $vmName