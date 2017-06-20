param([string]$vmName="*")

$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

function Generate-DSCArchive($vmName) {
    $dscSourceFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\dsc" -Resolve

    if (Test-Path $dscSourceFolder) {
        $dscSourceFilePaths = @(Get-ChildItem $dscSourceFolder -File -Filter "*$vmName*.ps1" | ForEach-Object -Process {$_.FullName})
        foreach ($dscSourceFilePath in $dscSourceFilePaths) {
            $dscArchiveFilePath = $dscSourceFilePath.Substring(0, $dscSourceFilePath.Length - 4) + ".zip"
            Publish-AzureRmVMDscConfiguration $dscSourceFilePath -OutputArchivePath $dscArchiveFilePath -Force -Verbose
        }
    }
}

Generate-DSCArchive $vmName