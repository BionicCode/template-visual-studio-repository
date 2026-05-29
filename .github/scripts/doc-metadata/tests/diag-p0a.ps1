#requires -Version 7.0
# Temporary diagnostic script for P0-A failing tests. Remove before final commit.
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\.."))
$ToolingSource = Join-Path $RepositoryRoot ".github\scripts\doc-metadata"
$PublicSurfaceSource = Join-Path $RepositoryRoot ".github\tools\doc-metadata"

function Write-Step { param([string] $Msg) Write-Host "`n=== $Msg ===" }
function Write-Diag { param([string] $Msg) Write-Host "[DIAG] $Msg" }

function Invoke-Process {
    param([string] $FileName, [string[]] $Arguments, [string] $WorkingDirectory, [hashtable] $Environment = @{})
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($a in $Arguments) { [void] $startInfo.ArgumentList.Add($a) }
    foreach ($k in $Environment.Keys) { $startInfo.Environment[$k] = [string] $Environment[$k] }
    $p = [System.Diagnostics.Process]::Start($startInfo)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ ExitCode = $p.ExitCode; Stdout = $out; Stderr = $err }
}

function Invoke-Git {
    param([string] $Root, [string[]] $Arguments)
    $r = Invoke-Process -FileName "git" -Arguments $Arguments -WorkingDirectory $Root
    if ($r.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($r.Stderr)" }
    $r.Stdout
}

function Invoke-Tool {
    param([string] $Root, [string] $Mode, [string[]] $Extra, [hashtable] $Env = @{})
    $script = Join-Path $Root ".github\scripts\doc-metadata\update-doc-metadata.ps1"
    $args = @("-NoLogo", "-NoProfile", "-File", $script, "-Mode", $Mode, "-Root", $Root) + $Extra
    Invoke-Process -FileName "pwsh" -Arguments $args -WorkingDirectory $Root -Environment $Env
}

function New-Repo {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "diag-p0a-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root ".github\scripts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root ".github\tools") -Force | Out-Null
    Copy-Item -LiteralPath $ToolingSource -Destination (Join-Path $root ".github\scripts\doc-metadata") -Recurse
    Copy-Item -LiteralPath $PublicSurfaceSource -Destination (Join-Path $root ".github\tools\doc-metadata") -Recurse
    $manifestPath = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
    $manifest.include = @("README.md", "docs/**/*", "AGENTS.*", "**/*.txt")
    $manifest.exclude = @()
    $manifest | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    Invoke-Git -Root $root -Arguments @("init", "-q") | Out-Null
    Invoke-Git -Root $root -Arguments @("config", "user.email", "doc-tests@example.invalid") | Out-Null
    Invoke-Git -Root $root -Arguments @("config", "user.name", "Doc Metadata Tests") | Out-Null
    $root
}

function Write-File { param([string] $Path, [string] $Content)
    $d = Split-Path -Parent $Path
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding utf8NoBOM
}

function Write-LinkMap { param([string] $Root, [hashtable] $Links)
    $p = Join-Path $Root "links.json"
    $Links | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding utf8NoBOM
    $p
}

function Commit-All { param([string] $Root, [string] $Msg = "test commit")
    Invoke-Git -Root $Root -Arguments @("add", ".") | Out-Null
    Invoke-Git -Root $Root -Arguments @("commit", "-q", "-m", $Msg) | Out-Null
}

function Get-MarkdownWithMetadata {
    param(
        [string] $Version = "1",
        [string] $Created = "2026-01-01T00:00:00+00:00",
        [string] $Updated = "2026-01-01T00:00:00+00:00",
        [string] $Author = "Doc Metadata Tests",
        [string] $Body = "# Title`n",
        [string] $CurrentChangesUrl = "",
        [string] $CurrentChangesLinkText = "View Commit",
        [string[]] $HistoryLines = @()
    )
    $currentLink = if ([string]::IsNullOrWhiteSpace($CurrentChangesUrl)) { "" } else { "> [<b>$CurrentChangesLinkText</b>]($CurrentChangesUrl)`n`n" }
    $historyBlock = if ($HistoryLines.Count -gt 0) { ($HistoryLines -join "`n") + "`n`n" } else { "" }
    "---`nVersion: $Version`nCreated: $Created`nUpdated: $Updated`nAuthor: $Author`n---`n<!-- doc-metadata-presentation:start -->`n$currentLink<details>`n<summary>Change History</summary>`n`n$historyBlock</details>`n`n---`n`n<br>`n<br>`n<!-- doc-metadata-presentation:end -->`n`n$Body"
}

# ─── TEST 1: Body change without reliable context clears stale current View Commit ───
Write-Step "TEST 1: Body change without reliable context"
$root1 = New-Repo
$readme1 = Join-Path $root1 "README.md"
Write-File -Path $readme1 -Content (Get-MarkdownWithMetadata -Version "1")
Commit-All -Root $root1
$base1 = (Invoke-Git -Root $root1 -Arguments @("rev-parse", "HEAD")).Trim()

Write-File -Path $readme1 -Content (Get-MarkdownWithMetadata -Version "1" -Body "# Title`nContent version with proven link.`n")
Commit-All -Root $root1 -Message "content version two"
$bodyCommit1 = (Invoke-Git -Root $root1 -Arguments @("rev-parse", "HEAD")).Trim()
Write-Diag "bodyCommit=$bodyCommit1"

$linkMap1 = Write-LinkMap -Root $root1 -Links @{
    "README.md" = @{
        path = "README.md"
        url = "https://github.com/example/repo/commit/$bodyCommit1"
        linkText = "View Commit"
        context = "local:$bodyCommit1"
        commitSha = $bodyCommit1
        bodyChanged = $true
    }
}

$linkedUpdate = Invoke-Tool -Root $root1 -Mode "Update" -Extra @("-Path", "README.md", "-BaseSha", $base1, "-HeadSha", $bodyCommit1, "-HistoryLinkMapPath", $linkMap1) -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "linkedUpdate.ExitCode=$($linkedUpdate.ExitCode)"
if ($linkedUpdate.ExitCode -ne 0) { Write-Diag "linkedUpdate.Stdout=$($linkedUpdate.Stdout)" }
$linkedContent = Get-Content -LiteralPath $readme1 -Raw
Write-Diag "After linked update, current link present: $(($linkedContent -match "(?m)^> \[<b>View Commit</b>\]"))"
Commit-All -Root $root1 -Message "metadata version two"

$changedBody = (Get-Content -LiteralPath $readme1 -Raw).Replace("Content version with proven link.", "Content version without reliable link.")
Write-File -Path $readme1 -Content $changedBody

$invalidLinkMap1 = Write-LinkMap -Root $root1 -Links @{
    "README.md" = @{
        path = "docs/other.md"
        url = "https://github.com/example/repo/commit/$bodyCommit1"
        linkText = "View Commit"
        context = "local:$bodyCommit1"
        commitSha = $bodyCommit1
        bodyChanged = $true
    }
}

$result1 = Invoke-Tool -Root $root1 -Mode "Update" -Extra @("-Path", "README.md", "-HistoryLinkMapPath", $invalidLinkMap1) -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "result1.ExitCode=$($result1.ExitCode)"
Write-Diag "result1.Stdout=$($result1.Stdout)"
$content1 = Get-Content -LiteralPath $readme1 -Raw
Write-Diag "Final content:"
Write-Host $content1
Write-Diag "URL in content: $(($content1 -match "https://github.com/example/repo/commit/$bodyCommit1"))"
Write-Diag "Version 3: $(($content1 -match 'Version: 3'))"
Write-Diag "current link absent: $(($content1 -notmatch '(?m)^> \[<b>View Commit</b>\]'))"
Write-Diag "history count: $([regex]::Matches($content1, '(?m)^- Updated:').Count)"

# ─── TEST 2: Metadata-only presentation repair ───
Write-Step "TEST 2: Metadata-only presentation repair"
$root2 = New-Repo
$readme2 = Join-Path $root2 "README.md"
Write-File -Path $readme2 -Content (Get-MarkdownWithMetadata -Version "1")
Commit-All -Root $root2
$base2 = (Invoke-Git -Root $root2 -Arguments @("rev-parse", "HEAD")).Trim()

Write-File -Path $readme2 -Content (Get-MarkdownWithMetadata -Version "1" -Body "# Title`nContent version with proven link.`n")
Commit-All -Root $root2 -Message "content version"
$bodyCommit2 = (Invoke-Git -Root $root2 -Arguments @("rev-parse", "HEAD")).Trim()
Write-Diag "bodyCommit2=$bodyCommit2"

$linkMap2 = Write-LinkMap -Root $root2 -Links @{
    "README.md" = @{
        path = "README.md"
        url = "https://github.com/example/repo/commit/$bodyCommit2"
        linkText = "View Commit"
        context = "local:$bodyCommit2"
        commitSha = $bodyCommit2
        bodyChanged = $true
    }
}

$contentUpdate2 = Invoke-Tool -Root $root2 -Mode "Update" -Extra @("-Path", "README.md", "-BaseSha", $base2, "-HeadSha", $bodyCommit2, "-HistoryLinkMapPath", $linkMap2) -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "contentUpdate2.ExitCode=$($contentUpdate2.ExitCode)"
Commit-All -Root $root2 -Message "metadata update"

$contentAfterUpdate = Get-Content -LiteralPath $readme2 -Raw
Write-Diag "After update, file content:"
Write-Host $contentAfterUpdate

$modified2 = ($contentAfterUpdate) -replace "<!-- doc-metadata-presentation:end -->\r?\n\r?\n", "<!-- doc-metadata-presentation:end -->`n"
Write-File -Path $readme2 -Content $modified2
Write-Diag "Modified file content (blank line removed):"
Write-Host $modified2

$result2 = Invoke-Tool -Root $root2 -Mode "Update" -Extra @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json") -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "result2.ExitCode=$($result2.ExitCode)"
Write-Diag "result2.Stdout=$($result2.Stdout)"
$after2 = Get-Content -LiteralPath $readme2 -Raw
Write-Diag "Final content after repair:"
Write-Host $after2
Write-Diag "URL in content: $(($after2 -match "\[<b>View Commit</b>\]\(https://github.com/example/repo/commit/$bodyCommit2\)"))"

# ─── TEST 3: Generated history tamper restored from trusted previous ───
Write-Step "TEST 3: History tamper restore"
$root3 = New-Repo
$readme3 = Join-Path $root3 "README.md"
Write-File -Path $readme3 -Content (Get-MarkdownWithMetadata -Version "1")
Commit-All -Root $root3
$base3 = (Invoke-Git -Root $root3 -Arguments @("rev-parse", "HEAD")).Trim()

Write-File -Path $readme3 -Content (Get-MarkdownWithMetadata -Version "1" -Body "# Title`nContent version with proven history.`n")
Commit-All -Root $root3 -Message "content version"
$bodyCommit3 = (Invoke-Git -Root $root3 -Arguments @("rev-parse", "HEAD")).Trim()
Write-Diag "bodyCommit3=$bodyCommit3"

$linkMap3 = Write-LinkMap -Root $root3 -Links @{
    "README.md" = @{
        path = "README.md"
        url = "https://github.com/example/repo/commit/$bodyCommit3"
        linkText = "View Commit"
        context = "local:$bodyCommit3"
        commitSha = $bodyCommit3
        bodyChanged = $true
    }
}

$contentUpdate3 = Invoke-Tool -Root $root3 -Mode "Update" -Extra @("-Path", "README.md", "-BaseSha", $base3, "-HeadSha", $bodyCommit3, "-HistoryLinkMapPath", $linkMap3) -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "contentUpdate3.ExitCode=$($contentUpdate3.ExitCode)"
Commit-All -Root $root3 -Message "metadata with proven history"

$tampered = (Get-Content -LiteralPath $readme3 -Raw).Replace("https://github.com/example/repo/commit/$bodyCommit3", "https://github.com/example/example")
Write-File -Path $readme3 -Content $tampered
Write-Diag "Tampered content:"
Write-Host $tampered

$result3 = Invoke-Tool -Root $root3 -Mode "Update" -Extra @("-Path", "README.md", "-ReportOutputPath", "report.json") -Env @{ GITHUB_REPOSITORY = "example/repo"; GITHUB_SERVER_URL = "https://github.com" }
Write-Diag "result3.ExitCode=$($result3.ExitCode)"
Write-Diag "result3.Stdout=$($result3.Stdout)"
$content3 = Get-Content -LiteralPath $readme3 -Raw
Write-Diag "Final content after tamper restore:"
Write-Host $content3
Write-Diag "URL in content: $(($content3 -match "\[<b>View Commit</b>\]\(https://github.com/example/repo/commit/$bodyCommit3\)"))"

Write-Host "`nDiagnostic complete."
