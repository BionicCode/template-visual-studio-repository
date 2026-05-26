#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\.."))
$ToolingSource = Join-Path $RepositoryRoot ".github\scripts\doc-metadata"
$PublicSurfaceSource = Join-Path $RepositoryRoot ".github\tools\doc-metadata"
$WorkflowPath = Join-Path $RepositoryRoot ".github\workflows\doc-metadata.yml"

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param([object] $Expected, [object] $Actual, [string] $Message)
    if ($Expected -ne $Actual) { throw "$Message Expected '$Expected' but got '$Actual'." }
}

function Invoke-Test {
    param([string] $Name, [scriptblock] $Body)
    try {
        & $Body
        $script:Passed++
        Write-Host "PASS $Name"
    }
    catch {
        $script:Failed++
        Write-Host "FAIL $Name"
        Write-Host "  $($_.Exception.Message)"
    }
}

function Invoke-Process {
    param(
        [string] $FileName,
        [string[]] $Arguments,
        [string] $WorkingDirectory,
        [hashtable] $Environment = @{}
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void] $startInfo.ArgumentList.Add($argument) }
    foreach ($key in $Environment.Keys) { $startInfo.Environment[$key] = [string] $Environment[$key] }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
}

function Invoke-Git {
    param([string] $Root, [string[]] $Arguments)
    $result = Invoke-Process -FileName "git" -Arguments $Arguments -WorkingDirectory $Root
    if ($result.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($result.Stderr)" }
    $result.Stdout
}

function New-TestRepository {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "doc-metadata-tests-$([guid]::NewGuid().ToString('N'))"
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

function Write-Utf8File {
    param([string] $Path, [string] $Content)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding utf8NoBOM
}

function Write-InvalidUtf8File {
    param([string] $Path)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [System.IO.File]::WriteAllBytes($Path, [byte[]]@(0xFF, 0xFE, 0xFD))
}

function Commit-All {
    param([string] $Root, [string] $Message = "test commit")
    Invoke-Git -Root $Root -Arguments @("add", ".") | Out-Null
    Invoke-Git -Root $Root -Arguments @("commit", "-q", "-m", $Message) | Out-Null
}

function Invoke-Tool {
    param(
        [string] $Root,
        [string] $Mode,
        [string[]] $ExtraArguments = @(),
        [hashtable] $Environment = @{}
    )

    $scriptPath = Join-Path $Root ".github\scripts\doc-metadata\update-doc-metadata.ps1"
    $arguments = @("-NoLogo", "-NoProfile", "-File", $scriptPath, "-Mode", $Mode, "-Root", $Root) + $ExtraArguments
    Invoke-Process -FileName "pwsh" -Arguments $arguments -WorkingDirectory $Root -Environment $Environment
}

function Read-JsonFile {
    param([string] $Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 32
}

function Get-MarkdownWithMetadata {
    param(
        [string] $Version = "1",
        [string] $Created = "2026-01-01T00:00:00+00:00",
        [string] $Updated = "2026-01-01T00:00:00+00:00",
        [string] $Author = "Doc Metadata Tests",
        [string] $Body = "# Title`n"
    )

    "---`nVersion: $Version`nCreated: $Created`nUpdated: $Updated`nAuthor: $Author`n---`n<!-- doc-metadata-presentation:start -->`n<details>`n<summary>Change History</summary>`n`n- Updated: <b>$Updated</b> | Author: <b>$Author</b> | Changes: <b>Unavailable</b>`n`n</details>`n`n---`n`n<br>`n<br>`n<!-- doc-metadata-presentation:end -->`n$Body"
}

Invoke-Test "Bootstrap initializes Markdown with human metadata, Author, UTC, and rich presentation" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $content = Get-Content -LiteralPath (Join-Path $root "README.md") -Raw
    Assert-True ($content -match "Version: 1") "Version should be initialized."
    Assert-True ($content -match "Author: Doc Metadata Tests") "Author should use git config user.name."
    Assert-True ($content -match "Created: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00") "Created should be UTC +00:00."
    Assert-True ($content -match "<!-- doc-metadata-presentation:start -->") "Markdown presentation region should be generated."
    Assert-Equal 2 ([regex]::Matches($content, "(?m)^<br>$").Count) "Markdown spacingBreaks 2 should emit exactly two <br> lines."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal $null $report.updatedFiles[0].oldVersion "Initialized old version should be null."
    Assert-Equal "1" ([string] $report.updatedFiles[0].newVersion) "Initialized new version should be 1."
}

Invoke-Test "Plain text gets compact metadata, physical blank lines, and no HTML" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "notes.txt") -Content "Document body starts here.`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-Path", "notes.txt")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $content = Get-Content -LiteralPath (Join-Path $root "notes.txt") -Raw
    Assert-True ($content -match "Version: 1") "Text metadata should use human fields."
    Assert-True ($content -match "--------------------------------------------------------------------------------") "Text separator should be generated."
    Assert-True ($content -notmatch "<br>" -and $content -notmatch "<details>") "Text files must not receive Markdown/HTML presentation."
    Assert-True ($content -match "--------------------------------------------------------------------------------\r?\n\r?\n\r?\nDocument body starts here\.") "Text spacingBreaks 2 should emit exactly two physical blank lines."
}

Invoke-Test "Body change after dotted version increments first component and refreshes Author" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2.1.2")
    Commit-All -Root $root
    Invoke-Git -Root $root -Arguments @("config", "user.name", "Content Author") | Out-Null
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2.1.2" -Body "# Title`nChanged.`n")

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Update should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "Version: 3") "Automatic increment should collapse 2.1.2 to 3."
    Assert-True ($content -match "Author: Content Author") "Author should refresh on body change."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal "2.1.2" ([string] $report.updatedFiles[0].oldVersion) "Report should include old dotted version."
    Assert-Equal "3" ([string] $report.updatedFiles[0].newVersion) "Report should include new major version."
}

Invoke-Test "Manual dotted version rebaseline is no-write when body and metadata are otherwise stable" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2.1")

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json")

    Assert-Equal 0 $result.ExitCode "Manual dotted rebaseline should pass."
    Assert-True ($result.Stdout -match "manual version rebaseline") "Report should mention manual rebaseline."
    $changed = Read-JsonFile (Join-Path $root "changed.json")
    Assert-Equal 0 @($changed.changedFiles).Count "Changed files should stay empty for no-write rebaseline."
}

Invoke-Test "Version decrease is rejected" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2.1")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "2")

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md")

    Assert-True ($result.ExitCode -ne 0) "Version decrease should fail."
    Assert-True ($result.Stdout -match "Version must not decrease") "Failure should name Version decrease."
}

Invoke-Test "Generated history tamper is restored from trusted previous presentation" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-MarkdownWithMetadata -Version "1")
    Commit-All -Root $root
    $tampered = (Get-Content -LiteralPath $readme -Raw).Replace("Changes: <b>Unavailable</b>", "Changes: [<b>View Commit</b>](https://github.com/example/example)")
    Write-Utf8File -Path $readme -Content $tampered

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Safe history tamper restore should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "Changes: <b>Unavailable</b>") "Generated history should be restored from previous trusted presentation."
    Assert-True ($content -notmatch "github.com/example/example") "Tampered URL should be removed."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-True ($report.updatedFiles[0].reason -match "historyTamperDetected" -and $report.updatedFiles[0].reason -match "historyRestoredFromTrustedPrevious") "Report should include history tamper categories."
}

Invoke-Test "Custom front matter fields are preserved and ignored" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content "---`nVersion: 1`nCreated: 2026-01-01T00:00:00+00:00`nUpdated: 2026-01-01T00:00:00+00:00`nAuthor: Doc Metadata Tests`nTool: Visual Studio Code`nReviewState: Draft`n---`n# Title`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-Path", "README.md")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "Tool: Visual Studio Code" -and $content -match "ReviewState: Draft") "Custom fields should be preserved."
}

Invoke-Test "Manifest removes overrides and uses include object scoped configuration" {
    $root = New-TestRepository
    $manifestPath = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
    $manifest | Add-Member -NotePropertyName overrides -NotePropertyValue @()
    $manifest | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

    $invalid = Invoke-Tool -Root $root -Mode "Check"
    Assert-True ($invalid.ExitCode -ne 0) "overrides should be rejected as unknown."

    $manifest = Get-Content -LiteralPath (Join-Path $PublicSurfaceSource "doc-metadata-manifest.json") -Raw | ConvertFrom-Json -Depth 32
    $manifest.include = @(
        [pscustomobject]@{
            pattern = "README.md"
            presentation = [pscustomobject]@{ includeSeparator = $false; spacingBreaks = 1 }
        }
    )
    $manifest.exclude = @()
    $manifest | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"

    $valid = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-Path", "README.md")
    Assert-Equal 0 $valid.ExitCode "Include object scoped presentation should pass."
    $content = Get-Content -LiteralPath (Join-Path $root "README.md") -Raw
    Assert-Equal 1 ([regex]::Matches($content, "(?m)^<br>$").Count) "Scoped spacingBreaks override should apply."
    Assert-True ($content -notmatch "(?m)^---\r?$`r?`n<br>") "Scoped includeSeparator false should remove presentation separator."
}

Invoke-Test "Conflicting multiple include entries fail" {
    $root = New-TestRepository
    $manifestPath = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
    $manifest.include = @(
        "README.md",
        [pscustomobject]@{ pattern = "README.md"; presentation = [pscustomobject]@{ spacingBreaks = 1 } }
    )
    $manifest.exclude = @()
    $manifest | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"

    Assert-True ($result.ExitCode -ne 0) "Conflicting include configs should fail."
    Assert-True ($result.Stdout -match "include configuration conflict") "Conflict should be reported."
}

Invoke-Test "Default exclude is empty and broad include plus exclude works" {
    $manifest = Read-JsonFile (Join-Path $PublicSurfaceSource "doc-metadata-manifest.json")
    Assert-Equal 0 @($manifest.exclude).Count "Default manifest exclude should be empty."

    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "docs\keep.md") -Content "# Keep`n"
    Write-Utf8File -Path (Join-Path $root "docs\skip.md") -Content "# Skip`n"
    $manifestPath = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("docs/**/*.md")
    $json.exclude = @("docs/skip.md")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $updated = @((Read-JsonFile (Join-Path $root "report.json")).updatedFiles.path)
    Assert-True ($updated -contains "docs/keep.md") "Included file should be updated."
    Assert-True ($updated -notcontains "docs/skip.md") "Excluded file should not be updated."
}

Invoke-Test "Eligibility processes only eligible files from AGENTS glob" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "AGENTS.md") -Content "# Agents`n"
    Write-Utf8File -Path (Join-Path $root "AGENTS.cs") -Content "class Agents { }`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass with ineligible report."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-True (@($report.updatedFiles.path) -contains "AGENTS.md") "AGENTS.md should be governed."
    Assert-True (@($report.updatedFiles.path) -notcontains "AGENTS.cs") "AGENTS.cs must not be modified."
    Assert-True (@($report.ineligibleFiles.path) -contains "AGENTS.cs") "AGENTS.cs should be reported ineligible."
}

Invoke-Test "Invalid UTF-8 is reported as binary non-text and never rewritten" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-InvalidUtf8File -Path $readme
    $before = [Convert]::ToHexString([System.IO.File]::ReadAllBytes($readme))

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Invalid UTF-8 should be ignored by default."
    $after = [Convert]::ToHexString([System.IO.File]::ReadAllBytes($readme))
    Assert-Equal $before $after "Invalid UTF-8 file should not be rewritten."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal 1 $report.ignoredBinaryOrNonText.Count "Invalid UTF-8 should be classified as binary/non-text."
}

Invoke-Test "GitHub summary and changed-files output contracts remain stable" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"
    $summaryPath = Join-Path $root "summary.md"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json") -Environment @{ GITHUB_STEP_SUMMARY = $summaryPath }

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    Assert-True (Test-Path -LiteralPath $summaryPath) "GitHub summary should be written."
    $changed = Read-JsonFile (Join-Path $root "changed.json")
    Assert-Equal "README.md" $changed.changedFiles[0] "ChangedFilesOutputPath should contain only updated paths."
}

Invoke-Test "Workflow preserves repair design and deterministic branch hash" {
    $workflow = Get-Content -LiteralPath $WorkflowPath -Raw

    Assert-True ($workflow -match "analyze-document-metadata") "Workflow should include analyze job."
    Assert-True ($workflow -match "repair-document-metadata") "Workflow should include repair job."
    Assert-True ($workflow -match "final-document-metadata-status") "Workflow should include final status job."
    Assert-True ($workflow -match "analyze-document-metadata:[\s\S]*?permissions:\s*\r?\n\s+contents: read") "Analyze job should use contents: read."
    Assert-True ($workflow -match "repair-document-metadata:[\s\S]*?permissions:\s*\r?\n\s+contents: write\s*\r?\n\s+pull-requests: write") "Repair job should have write permissions only in repair job."
    Assert-True ($workflow -notmatch "pull_request_target") "Workflow must not use pull_request_target."
    Assert-True ($workflow -match "path: trusted" -and $workflow -match "path: work") "Workflow should use trusted/work checkout layout."
    Assert-True ($workflow -match 'codex/doc-metadata-repair/\$safeTarget-\$hash') "Workflow should use the required repair branch prefix and hash suffix."
    Assert-True ($workflow -match "SHA256" -and $workflow -match "ToHexString" -and $workflow -match "Substring\(0, 12\)") "Workflow should construct a stable SHA-256 branch hash."
    Assert-True ($workflow -notmatch 'doc-metadata/repair/\$safeTarget') "Workflow must not use the old repair branch prefix."
    Assert-True ($workflow -match "Post-repair Check") "Workflow should run mandatory post-repair Check."
    Assert-True ($workflow -match "doc-metadata-links.json") "Workflow should pass stable history links to the trusted script."
}

Write-Host ""
Write-Host "Doc metadata acceptance tests: $script:Passed passed, $script:Failed failed"

if ($script:Failed -gt 0) {
    exit 1
}
