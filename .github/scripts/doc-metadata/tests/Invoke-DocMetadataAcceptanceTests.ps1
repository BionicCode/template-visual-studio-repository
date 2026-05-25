#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\.."))
$ToolingSource = Join-Path $RepositoryRoot ".github\scripts\doc-metadata"
$PublicSurfaceSource = Join-Path $RepositoryRoot ".github\doc-metadata"
$WorkflowPath = Join-Path $RepositoryRoot ".github\workflows\doc-metadata.yml"

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [object] $Expected,
        [object] $Actual,
        [string] $Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected' but got '$Actual'."
    }
}

function Invoke-Test {
    param(
        [string] $Name,
        [scriptblock] $Body
    )

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

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = $FileName
    $processStartInfo.WorkingDirectory = $WorkingDirectory
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void] $processStartInfo.ArgumentList.Add($argument)
    }
    foreach ($key in $Environment.Keys) {
        $processStartInfo.Environment[$key] = [string] $Environment[$key]
    }

    $process = [System.Diagnostics.Process]::Start($processStartInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

function Invoke-Git {
    param(
        [string] $Root,
        [string[]] $Arguments
    )

    $result = Invoke-Process -FileName "git" -Arguments $Arguments -WorkingDirectory $Root
    if ($result.ExitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($result.Stderr)"
    }

    $result.Stdout
}

function New-TestRepository {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "doc-metadata-tests-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root ".github\scripts") -Force | Out-Null
    Copy-Item -LiteralPath $ToolingSource -Destination (Join-Path $root ".github\scripts\doc-metadata") -Recurse
    Copy-Item -LiteralPath $PublicSurfaceSource -Destination (Join-Path $root ".github\doc-metadata") -Recurse
    Invoke-Git -Root $root -Arguments @("init", "-q") | Out-Null
    Invoke-Git -Root $root -Arguments @("config", "user.email", "doc-tests@example.invalid") | Out-Null
    Invoke-Git -Root $root -Arguments @("config", "user.name", "Doc Metadata Tests") | Out-Null
    $root
}

function Write-Utf8File {
    param(
        [string] $Path,
        [string] $Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding utf8NoBOM
}

function Write-InvalidUtf8File {
    param([string] $Path)

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllBytes($Path, [byte[]]@(0xFF, 0xFE, 0xFD))
}

function Commit-All {
    param(
        [string] $Root,
        [string] $Message = "test commit"
    )

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

function Get-ReadmeWithMetadata {
    param(
        [int] $Version = 1,
        [string] $Created = "2026-01-01T00:00:00+00:00",
        [string] $Updated = "2026-01-01T00:00:00+00:00",
        [string] $Body = "# Title`n"
    )

    "---`ndoc_version: $Version`ncreated: $Created`nupdated: $Updated`n---`n$Body"
}

Invoke-Test "Bootstrap initializes existing governed Markdown without metadata and reports old null" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"
    $reportPath = Join-Path $root "report.json"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $report = Read-JsonFile $reportPath
    Assert-Equal 1 $report.updatedFiles.Count "Expected one updated file."
    Assert-Equal $null $report.updatedFiles[0].oldDocVersion "Old version should be null for initialized files."
    Assert-Equal 1 $report.updatedFiles[0].newDocVersion "New version should be 1."
    Assert-True ($result.Stdout -match "OldVersion" -and $result.Stdout -match "missing") "Console report should render missing old values."
}

Invoke-Test "Check fails existing governed Markdown without metadata with remediation" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"

    $result = Invoke-Tool -Root $root -Mode "Check"

    Assert-True ($result.ExitCode -ne 0) "Check should fail."
    Assert-True ($result.Stdout -match "metadata block exists") "Check should report missing metadata."
    Assert-True ($result.Stdout -match "pwsh ./\.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .") "Check should print remediation."
}

Invoke-Test "Bootstrap preserves existing valid metadata" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata)
    $before = Get-Content -LiteralPath $readme -Raw

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    Assert-Equal $before (Get-Content -LiteralPath $readme -Raw) "Bootstrap should not rewrite valid metadata."
}

Invoke-Test "Update increments version and timestamp when body changes" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Updated "2026-01-01T00:00:00+00:00")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Updated "2026-01-01T00:00:00+00:00" -Body "# Title`nChanged.`n")
    $reportPath = Join-Path $root "report.json"

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Update should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "doc_version: 2") "Version should increment to 2."
    $report = Read-JsonFile $reportPath
    Assert-Equal 1 $report.updatedFiles[0].oldDocVersion "Report old version should be 1."
    Assert-Equal 2 $report.updatedFiles[0].newDocVersion "Report new version should be 2."
    Assert-True ($report.updatedFiles[0].oldUpdated -ne $report.updatedFiles[0].newUpdated) "Updated timestamp should change."
}

Invoke-Test "Metadata-only manual version increase is reported without increment" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1)
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 20)
    $changedPath = Join-Path $root "changed.json"

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Manual rebaseline should pass."
    Assert-True ((Get-Content -LiteralPath $readme -Raw) -match "doc_version: 20") "Version 20 should be preserved."
    Assert-True ($result.Stdout -match "manual version rebaseline") "Report should mention manual rebaseline."
    $changed = Read-JsonFile $changedPath
    Assert-Equal 0 @($changed.changedFiles).Count "ChangedFilesOutputPath should contain no updated paths."
}

Invoke-Test "Version rollback is rejected" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 20)
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 2)

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md")

    Assert-True ($result.ExitCode -ne 0) "Rollback should fail."
    Assert-True ($result.Stdout -match "doc_version must not decrease") "Rollback rule should be reported."
}

Invoke-Test "Ungoverned existing Markdown is ignored" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "notes.md") -Content "# Notes`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    Assert-True ((Get-Content -LiteralPath (Join-Path $root "notes.md") -Raw) -notmatch "doc_version") "Ungoverned Markdown should not be modified."
}

Invoke-Test "Comment-block metadata can be placed at the bottom" {
    $root = New-TestRepository
    $spec = Join-Path $root "specs\example.txt"
    Write-Utf8File -Path $spec -Content "Specification body.`n"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-Path", "specs/example.txt")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $content = Get-Content -LiteralPath $spec -Raw
    Assert-True ($content.TrimEnd().EndsWith("-->")) "Comment block should be at the bottom."
    Assert-True ($content -match "<!-- doc-metadata") "Comment block should be present."
}

Invoke-Test "Invalid UTF-8 is never rewritten" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-InvalidUtf8File -Path $readme
    $before = [System.IO.File]::ReadAllBytes($readme)

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"
    $after = [System.IO.File]::ReadAllBytes($readme)

    Assert-True ($result.ExitCode -ne 0) "Invalid UTF-8 should fail."
    Assert-True ($result.Stdout -match "invalid UTF-8") "Invalid UTF-8 should be reported."
    Assert-Equal ([Convert]::ToHexString($before)) ([Convert]::ToHexString($after)) "Invalid UTF-8 file should not be rewritten."
}

Invoke-Test "Invalid manifest fails before touching files" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content "# Title`n"
    $manifest = Join-Path $root ".github\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.PSObject.Properties.Remove("defaults")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"

    Assert-True ($result.ExitCode -ne 0) "Invalid manifest should fail."
    Assert-True ((Get-Content -LiteralPath $readme -Raw) -notmatch "doc_version") "File should not be touched."
}

Invoke-Test "Manifest rejects front matter at bottom and accepts comment block bottom" {
    $root = New-TestRepository
    $manifest = Join-Path $root ".github\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.defaults.metadataPlacement = "bottom"
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $invalid = Invoke-Tool -Root $root -Mode "Check"

    Assert-True ($invalid.ExitCode -ne 0) "YAML front matter bottom placement should fail."

    Copy-Item -LiteralPath (Join-Path $PublicSurfaceSource "doc-metadata-manifest.json") -Destination $manifest -Force
    $valid = Invoke-Tool -Root $root -Mode "Check"

    Assert-True ($valid.Stdout -notmatch "cannot use metadataPlacement 'bottom' with yaml-front-matter") "Comment-block bottom override should be accepted by manifest validation."
}

Invoke-Test "GitHub summary is written when requested" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"
    $summaryPath = Join-Path $root "summary.md"

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json") -Environment @{ GITHUB_STEP_SUMMARY = $summaryPath }

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    Assert-True (Test-Path -LiteralPath $summaryPath) "GitHub summary should be written."
    Assert-True ((Get-Content -LiteralPath $summaryPath -Raw) -match "Document metadata") "Summary should contain report heading."
}

Invoke-Test "Pull request event comparison uses payload base and head SHAs" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Updated "2026-01-01T00:00:00+00:00")
    Commit-All -Root $root -Message "base"
    $baseSha = (Invoke-Git -Root $root -Arguments @("rev-parse", "HEAD")).Trim()
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 2 -Updated "2026-01-02T00:00:00+00:00" -Body "# Title`nChanged.`n")
    Commit-All -Root $root -Message "head"
    $headSha = (Invoke-Git -Root $root -Arguments @("rev-parse", "HEAD")).Trim()
    $payloadPath = Join-Path $root "event.json"
    @{
        pull_request = @{
            base = @{ sha = $baseSha }
            head = @{ sha = $headSha }
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Check" -ExtraArguments @("-EventName", "pull_request", "-EventPayloadPath", "event.json", "-HeadSha", "merge-sha-should-not-be-used")

    Assert-Equal 0 $result.ExitCode "Pull request comparison should pass."
    Assert-True ($result.Stdout -match "Comparison mode: pull_request") "Report should show pull_request comparison mode."
    Assert-True ($result.Stdout -match $headSha) "Report should use payload head SHA."
}

Invoke-Test "Pull request event fails when payload SHAs are not fetchable" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content (Get-ReadmeWithMetadata)
    Commit-All -Root $root
    $baseSha = (Invoke-Git -Root $root -Arguments @("rev-parse", "HEAD")).Trim()
    $payloadPath = Join-Path $root "event.json"
    @{
        pull_request = @{
            base = @{ sha = $baseSha }
            head = @{ sha = "ffffffffffffffffffffffffffffffffffffffff" }
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Check" -ExtraArguments @("-EventName", "pull_request", "-EventPayloadPath", "event.json", "-HeadSha", "merge-sha-should-not-be-used")

    Assert-True ($result.ExitCode -ne 0) "Unfetchable PR head should fail."
    Assert-True ($result.Stdout -match "not fetchable") "Failure should explain that the SHA is not fetchable."
}

Invoke-Test "Push event comparison uses before and head SHAs" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Updated "2026-01-01T00:00:00+00:00")
    Commit-All -Root $root -Message "before"
    $beforeSha = (Invoke-Git -Root $root -Arguments @("rev-parse", "HEAD")).Trim()
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 2 -Updated "2026-01-02T00:00:00+00:00" -Body "# Title`nChanged.`n")
    Commit-All -Root $root -Message "after"
    $afterSha = (Invoke-Git -Root $root -Arguments @("rev-parse", "HEAD")).Trim()
    $payloadPath = Join-Path $root "event.json"
    @{
        before = $beforeSha
        after = $afterSha
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Check" -ExtraArguments @("-EventName", "push", "-EventPayloadPath", "event.json", "-HeadSha", $afterSha)

    Assert-Equal 0 $result.ExitCode "Push comparison should pass."
    Assert-True ($result.Stdout -match "Comparison mode: push") "Report should show push comparison mode."
    Assert-True ($result.Stdout -match $beforeSha -and $result.Stdout -match $afterSha) "Report should include push before/head SHAs."
}

Invoke-Test "Workflow uses read-only checkout and event-aware inputs" {
    $workflow = Get-Content -LiteralPath $WorkflowPath -Raw

    Assert-True ($workflow -match "permissions:\s*\r?\n\s+contents: read") "Workflow should use contents: read."
    Assert-True ($workflow -notmatch "pull_request_target") "Workflow must not use pull_request_target."
    Assert-True ($workflow -notmatch "git push") "Workflow must not push."
    Assert-True ($workflow -match "actions/checkout@v6") "Workflow should use actions/checkout."
    Assert-True ($workflow -match "fetch-depth: 0") "Workflow should fetch history."
    Assert-True ($workflow -match "persist-credentials: false") "Workflow should disable credential persistence."
    Assert-True ($workflow -match "github.event_name" -and $workflow -match "github.event_path" -and $workflow -match "github.sha") "Workflow should pass event-aware comparison inputs."
    Assert-True ($workflow -match "specs/\*\*") "Workflow paths should cover specs."
}

Write-Host ""
Write-Host "Doc metadata acceptance tests: $script:Passed passed, $script:Failed failed"

if ($script:Failed -gt 0) {
    exit 1
}
