$errors = $null
[void] [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot '..\update-doc-metadata.ps1'),
    [ref] $null,
    [ref] $errors
)
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "ERROR: $($_.Message)" }
    exit 1
}
Write-Host 'PARSE OK'
