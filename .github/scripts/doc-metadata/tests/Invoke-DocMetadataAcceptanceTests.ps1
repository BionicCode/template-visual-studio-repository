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
    New-Item -ItemType Directory -Path (Join-Path $root ".github\tools") -Force | Out-Null
    Copy-Item -LiteralPath $ToolingSource -Destination (Join-Path $root ".github\scripts\doc-metadata") -Recurse
    Copy-Item -LiteralPath $PublicSurfaceSource -Destination (Join-Path $root ".github\tools\doc-metadata") -Recurse
    $manifestPath = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
    $manifest.include = @("README.md", "docs/**/*.md", "docs/**/*.markdown")
    $manifest | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
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
    Assert-True ((Get-Content -LiteralPath (Join-Path $root "README.md") -Raw).StartsWith("---`ndoc_version: 1")) "Initialized front matter should not include an empty first metadata line."
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

Invoke-Test "Update increments body change even when timestamp metadata is repairable" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Updated "2026-01-01T00:00:00+00:00")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content "---`ndoc_version: 1`ncreated: 2026-01-01T00:00:00+00:00`nupdated: not-a-timestamp`n---`n# Title`nChanged.`n"
    $reportPath = Join-Path $root "report.json"
    $changedPath = Join-Path $root "changed.json"

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Repairable timestamp error with body change should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "doc_version: 2") "Body change should increment doc_version."
    Assert-True ($content -notmatch "updated: not-a-timestamp") "Invalid updated timestamp should be repaired."
    $changed = Read-JsonFile $changedPath
    Assert-Equal "README.md" $changed.changedFiles[0] "Changed files should include README.md."
    $report = Read-JsonFile $reportPath
    Assert-True ($report.updatedFiles[0].reason -match "body changed" -and $report.updatedFiles[0].reason -match "metadata repaired") "Report reason should include body change and metadata repair."
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

Invoke-Test "Metadata-only manual version increase restores timestamp drift from valid previous metadata" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Created "2026-01-01T00:00:00+00:00" -Updated "2026-01-01T00:00:00+00:00")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 20 -Created "2026-01-02T00:00:00+00:00" -Updated "2026-01-02T00:00:00+00:00")
    $changedPath = Join-Path $root "changed.json"
    $reportPath = Join-Path $root "report.json"

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Safe timestamp restore should pass."
    $content = Get-Content -LiteralPath $readme -Raw
    Assert-True ($content -match "doc_version: 20") "Manual version 20 should be preserved."
    Assert-True ($content -match "created: 2026-01-01T00:00:00\+00:00") "Created timestamp should be restored from previous metadata."
    Assert-True ($content -match "updated: 2026-01-01T00:00:00\+00:00") "Updated timestamp should be restored from previous metadata."
    $changed = Read-JsonFile $changedPath
    Assert-Equal 1 @($changed.changedFiles).Count "ChangedFilesOutputPath should include the repaired file."
    Assert-Equal "README.md" $changed.changedFiles[0] "ChangedFilesOutputPath should contain README.md."
    $report = Read-JsonFile $reportPath
    Assert-Equal 20 $report.updatedFiles[0].oldDocVersion "Report old version should be the manually changed current version."
    Assert-Equal 20 $report.updatedFiles[0].newDocVersion "Report new version should preserve the manual baseline."
    $rawReport = Get-Content -LiteralPath $reportPath -Raw
    Assert-True ($rawReport -match '"oldUpdated":\s*"2026-01-02T00:00:00\+00:00"') "Report old updated timestamp should show the drifted value."
    Assert-True ($rawReport -match '"newUpdated":\s*"2026-01-01T00:00:00\+00:00"') "Report new updated timestamp should show the restored value."
    Assert-True ($report.updatedFiles[0].reason -match "manual version rebaseline") "Report should mention manual rebaseline."
}

Invoke-Test "Metadata-only manual version increase fails when timestamp drift cannot be safely restored" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 1 -Created "not-a-timestamp" -Updated "also-not-a-timestamp")
    Commit-All -Root $root
    Write-Utf8File -Path $readme -Content (Get-ReadmeWithMetadata -Version 20 -Created "2026-01-02T00:00:00+00:00" -Updated "2026-01-02T00:00:00+00:00")
    $before = Get-Content -LiteralPath $readme -Raw
    $changedPath = Join-Path $root "changed.json"
    $reportPath = Join-Path $root "report.json"

    $result = Invoke-Tool -Root $root -Mode "Update" -ExtraArguments @("-Path", "README.md", "-ChangedFilesOutputPath", "changed.json", "-ReportOutputPath", "report.json")
    $after = Get-Content -LiteralPath $readme -Raw

    Assert-True ($result.ExitCode -ne 0) "Unsafe timestamp restore should fail."
    Assert-Equal $before $after "Unsafe timestamp restore should not rewrite the file."
    Assert-True ($result.Stdout -match "timestamp drift could not be safely restored") "Failure should explain that timestamp drift could not be safely restored."
    $changed = Read-JsonFile $changedPath
    Assert-Equal 0 @($changed.changedFiles).Count "ChangedFilesOutputPath should remain empty on unsafe restore failure."
    $report = Read-JsonFile $reportPath
    Assert-True ($report.failedFiles[0].rule -match "timestamp drift could not be safely restored") "JSON report should include the unsafe restore failure."
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

Invoke-Test "Invalid UTF-8 is reported as binary non-text and never rewritten by default" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-InvalidUtf8File -Path $readme
    $before = [System.IO.File]::ReadAllBytes($readme)

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")
    $after = [System.IO.File]::ReadAllBytes($readme)

    Assert-Equal 0 $result.ExitCode "Invalid UTF-8 should be ignored by default eligibility policy."
    Assert-True ($result.Stdout -match "binary/non-text") "Binary/non-text should be reported."
    Assert-Equal ([Convert]::ToHexString($before)) ([Convert]::ToHexString($after)) "Invalid UTF-8 file should not be rewritten."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal 1 $report.ignoredBinaryOrNonText.Count "JSON report should classify invalid UTF-8 as ignoredBinaryOrNonText."
    Assert-True ($report.ignoredBinaryOrNonText[0].remediation -match "Convert this document to UTF-8") "Report should include UTF-8 conversion remediation."
}

Invoke-Test "Invalid manifest fails before touching files" {
    $root = New-TestRepository
    $readme = Join-Path $root "README.md"
    Write-Utf8File -Path $readme -Content "# Title`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.PSObject.Properties.Remove("defaults")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap"

    Assert-True ($result.ExitCode -ne 0) "Invalid manifest should fail."
    Assert-True ((Get-Content -LiteralPath $readme -Raw) -notmatch "doc_version") "File should not be touched."
}

Invoke-Test "Manifest rejects front matter at bottom and accepts comment block bottom" {
    $root = New-TestRepository
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.defaults.metadataPlacement = "bottom"
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $invalid = Invoke-Tool -Root $root -Mode "Check"

    Assert-True ($invalid.ExitCode -ne 0) "YAML front matter bottom placement should fail."

    Copy-Item -LiteralPath (Join-Path $PublicSurfaceSource "doc-metadata-manifest.json") -Destination $manifest -Force
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.overrides = @([pscustomobject]@{
        include = @("docs/**/*.md")
        metadataPlacement = "bottom"
    })
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $invalidInherited = Invoke-Tool -Root $root -Mode "Check" -ExtraArguments @("-ReportOutputPath", "invalid-inherited-report.json")
    $invalidInheritedReport = Read-JsonFile (Join-Path $root "invalid-inherited-report.json")

    Assert-True ($invalidInherited.ExitCode -ne 0) "Inherited YAML front matter bottom placement should fail."
    Assert-True ($invalidInheritedReport.failedFiles[0].current -match "cannot use metadataPlacement 'bottom' with yaml-front-matter") "Inherited YAML placement failure should be reported."

    Copy-Item -LiteralPath (Join-Path $PublicSurfaceSource "doc-metadata-manifest.json") -Destination $manifest -Force
    $valid = Invoke-Tool -Root $root -Mode "Check"

    Assert-True ($valid.Stdout -notmatch "cannot use metadataPlacement 'bottom' with yaml-front-matter") "Comment-block bottom override should be accepted by manifest validation."
}

Invoke-Test "Filename glob matches root agent files but not nested or lowercase variants" {
    $root = New-TestRepository
    foreach ($fileName in @("AGENTS.md", "AGENT_GUARDRAILS.md", "NET_AGENTS.md", "agents.md")) {
        Write-Utf8File -Path (Join-Path $root $fileName) -Content "# $fileName`n"
    }
    Write-Utf8File -Path (Join-Path $root "docs\AGENTS.md") -Content "# Nested AGENTS`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("*AGENT*.md")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $report = Read-JsonFile (Join-Path $root "report.json")
    $updatedPaths = @($report.updatedFiles.path)
    Assert-True ($updatedPaths -ccontains "AGENTS.md") "*AGENT*.md should match AGENTS.md."
    Assert-True ($updatedPaths -ccontains "AGENT_GUARDRAILS.md") "*AGENT*.md should match AGENT_GUARDRAILS.md."
    Assert-True ($updatedPaths -ccontains "NET_AGENTS.md") "*AGENT*.md should match NET_AGENTS.md."
    Assert-True ($updatedPaths -cnotcontains "docs/AGENTS.md") "*AGENT*.md should not cross directory separators."
    Assert-True ($updatedPaths -cnotcontains "agents.md") "Matching is case-sensitive, so lowercase agents.md should not match *AGENT*.md."
}

Invoke-Test "Recursive filename glob matches nested agent files" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "AGENTS.md") -Content "# Root AGENTS`n"
    Write-Utf8File -Path (Join-Path $root "docs\AGENTS.md") -Content "# Nested AGENTS`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("**/*AGENT*.md")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Bootstrap should pass."
    $report = Read-JsonFile (Join-Path $root "report.json")
    $updatedPaths = @($report.updatedFiles.path)
    Assert-True ($updatedPaths -ccontains "AGENTS.md") "**/*AGENT*.md should match root-level AGENTS.md."
    Assert-True ($updatedPaths -ccontains "docs/AGENTS.md") "**/*AGENT*.md should match nested docs/AGENTS.md."
}

Invoke-Test "Analyze classifies missing metadata as safe repair" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"

    $result = Invoke-Tool -Root $root -Mode "Analyze" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Analyze should exit 0 after reporting."
    Assert-True ($result.Stdout -match "Analysis: metadataValid=False, repairRequired=True, repairSafe=True") "Analyze report should classify safe repair."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal $false $report.analysis.metadataValid "Metadata should not be valid."
    Assert-Equal $true $report.analysis.repairRequired "Repair should be required."
    Assert-Equal $true $report.analysis.repairSafe "Repair should be safe."
    Assert-Equal "README.md" $report.analysis.repairableFiles[0].path "README.md should be repairable."
}

Invoke-Test "Eligibility processes only eligible files from broad AGENTS pattern" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "AGENTS.md") -Content "# Agents`n"
    Write-Utf8File -Path (Join-Path $root "AGENTS.cs") -Content "class Agents { }`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("AGENTS.*")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Broad AGENTS pattern should pass with ineligible file reported."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-True (@($report.updatedFiles.path) -contains "AGENTS.md") "AGENTS.md should be processed."
    Assert-True (@($report.updatedFiles.path) -notcontains "AGENTS.cs") "AGENTS.cs should not be processed."
    Assert-Equal "AGENTS.cs" $report.ineligibleFiles[0].path "AGENTS.cs should be reported as ineligible."
    Assert-Equal "extension not allowed" $report.ineligibleFiles[0].reason "AGENTS.cs should be rejected by extension."
}

Invoke-Test "Default eligibility allows Markdown and text but ignores source and config extensions" {
    $root = New-TestRepository
    foreach ($fileName in @("a.md", "b.markdown", "c.txt", "d.json", "e.cs", "f.csproj", "g.sln", "h.slnx", "i.js", "j.ts")) {
        Write-Utf8File -Path (Join-Path $root "docs\$fileName") -Content "content`n"
    }
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("docs/*")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Default eligibility should ignore non-document extensions without failing."
    $report = Read-JsonFile (Join-Path $root "report.json")
    $updatedPaths = @($report.updatedFiles.path)
    Assert-True ($updatedPaths -contains "docs/a.md" -and $updatedPaths -contains "docs/b.markdown" -and $updatedPaths -contains "docs/c.txt") "Default document extensions should be eligible."
    foreach ($fileName in @("d.json", "e.cs", "f.csproj", "g.sln", "h.slnx", "i.js", "j.ts")) {
        Assert-True ($updatedPaths -notcontains "docs/$fileName") "$fileName should not be modified by default."
    }
    Assert-Equal 7 $report.ineligibleFiles.Count "Seven source/config files should be reported as ineligible."
}

Invoke-Test "Eligibility supports additional allowed extensions and case-insensitive extension comparison" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "docs\guide.adoc") -Content "= Guide`n"
    Write-Utf8File -Path (Join-Path $root "README.MD") -Content "# Upper`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("docs/*.adoc", "*.MD")
    $json.documentEligibility.additionalAllowedExtensions = @("adoc")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Additional extension should be accepted."
    $updatedPaths = @((Read-JsonFile (Join-Path $root "report.json")).updatedFiles.path)
    Assert-True ($updatedPaths -contains "docs/guide.adoc") "Additional .adoc extension should be eligible."
    Assert-True ($updatedPaths -contains "README.MD") "Uppercase .MD extension should be eligible by case-insensitive extension comparison."
}

Invoke-Test "Eligibility allowedExtensions replaces defaults" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"
    Write-Utf8File -Path (Join-Path $root "docs\guide.adoc") -Content "= Guide`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("README.md", "docs/*.adoc")
    $json.documentEligibility.allowedExtensions = @(".adoc")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Replacement allowedExtensions should pass."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-True (@($report.updatedFiles.path) -contains "docs/guide.adoc") ".adoc should be eligible."
    Assert-True (@($report.ineligibleFiles.path) -contains "README.md") "README.md should be ineligible when defaults are replaced."
}

Invoke-Test "Eligibility denied extensions and denied paths win" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "README.md") -Content "# Title`n"
    Write-Utf8File -Path (Join-Path $root "docs\private.txt") -Content "private`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("README.md", "docs/*.txt")
    $json.documentEligibility.deniedExtensions = @(".md")
    $json.documentEligibility.deniedPaths = @("docs/private.txt")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $result = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report.json")

    Assert-Equal 0 $result.ExitCode "Denied eligibility should report but not fail by default."
    $report = Read-JsonFile (Join-Path $root "report.json")
    Assert-Equal 0 $report.updatedFiles.Count "Denied files should not be modified."
    Assert-Equal 1 $report.ignoredByDeniedExtension.Count "Denied extension should be grouped."
    Assert-Equal 1 $report.ignoredByDeniedPath.Count "Denied path should be grouped."
}

Invoke-Test "Eligibility extensionless and invalid extension configuration are enforced" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "NOTICE") -Content "Notice`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("NOTICE")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $defaultResult = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "default-report.json")
    Assert-Equal 0 $defaultResult.ExitCode "Extensionless should be reported without failing by default."
    Assert-Equal "extensionless not allowed" (Read-JsonFile (Join-Path $root "default-report.json")).ineligibleFiles[0].reason "Extensionless file should be ineligible by default."

    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.documentEligibility.allowExtensionless = $true
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM
    $allowedResult = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "allowed-report.json")
    Assert-Equal 0 $allowedResult.ExitCode "allowExtensionless should allow NOTICE."
    Assert-Equal "NOTICE" (Read-JsonFile (Join-Path $root "allowed-report.json")).updatedFiles[0].path "NOTICE should be updated when extensionless files are allowed."

    $json.documentEligibility.additionalAllowedExtensions = @("*.md")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM
    $invalidResult = Invoke-Tool -Root $root -Mode "Check" -ExtraArguments @("-ReportOutputPath", "invalid-extension-report.json")
    $invalidReport = Read-JsonFile (Join-Path $root "invalid-extension-report.json")
    Assert-True ($invalidResult.ExitCode -ne 0) "Wildcard extension configuration should be invalid."
    Assert-True ($invalidReport.failedFiles[0].current -match "must not contain wildcards") "Invalid extension diagnostic should be clear."
}

Invoke-Test "Eligibility failOnIneligibleMatches controls failure" {
    $root = New-TestRepository
    Write-Utf8File -Path (Join-Path $root "AGENTS.cs") -Content "class Agents { }`n"
    $manifest = Join-Path $root ".github\tools\doc-metadata\doc-metadata-manifest.json"
    $json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 32
    $json.include = @("AGENTS.*")
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM

    $reportOnly = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "report-only.json")
    Assert-Equal 0 $reportOnly.ExitCode "Ineligible matches should not fail by default."
    Assert-Equal 1 (Read-JsonFile (Join-Path $root "report-only.json")).ineligibleFiles.Count "Ineligible match should be reported."

    $json.documentEligibility.failOnIneligibleMatches = $true
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM
    $failResult = Invoke-Tool -Root $root -Mode "Bootstrap" -ExtraArguments @("-ReportOutputPath", "fail-report.json")
    Assert-True ($failResult.ExitCode -ne 0) "failOnIneligibleMatches should fail on ineligible matches."
    Assert-True ($failResult.Stdout -match "documentEligibility") "Failure should mention documentEligibility."
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

Invoke-Test "Workflow analyzes read-only and repairs through trusted worktree layout" {
    $workflow = Get-Content -LiteralPath $WorkflowPath -Raw

    Assert-True ($workflow -match "analyze-document-metadata") "Workflow should include analyze job."
    Assert-True ($workflow -match "repair-document-metadata") "Workflow should include repair job."
    Assert-True ($workflow -match "final-document-metadata-status") "Workflow should include final status job."
    Assert-True ($workflow -match "analyze-document-metadata:[\s\S]*?permissions:\s*\r?\n\s+contents: read") "Analyze job should use contents: read."
    Assert-True ($workflow -match "repair-document-metadata:[\s\S]*?permissions:\s*\r?\n\s+contents: write\s*\r?\n\s+pull-requests: write") "Repair job should have write permissions only in repair job."
    Assert-True ($workflow -notmatch "pull_request_target") "Workflow must not use pull_request_target."
    Assert-True ($workflow -match "actions/checkout@v6") "Workflow should use actions/checkout."
    Assert-True ($workflow -match "fetch-depth: 0") "Workflow should fetch history."
    Assert-True ($workflow -match "persist-credentials: false") "Workflow should disable credential persistence."
    Assert-True ($workflow -match "github.event_name" -and $workflow -match "github.event_path" -and $workflow -match "github.sha") "Workflow should pass event-aware comparison inputs."
    Assert-True ($workflow -match "specs/\*\*") "Workflow paths should cover specs."
    Assert-True ($workflow -match "path: trusted" -and $workflow -match "path: work") "Workflow should use trusted and work checkout layout."
    Assert-True ($workflow -match "github.event.pull_request.head.repo.full_name == github.repository") "Workflow should repair same-repository PRs only."
    Assert-True ($workflow -match "github.event.pull_request.head.ref") "Workflow should checkout and push to the PR head ref."
    Assert-True ($workflow -match "doc-metadata-repair") "Workflow should use deterministic repair branch naming/concurrency."
    Assert-True ($workflow -match "gh pr create" -and $workflow -match "gh pr edit") "Workflow should create or update bot repair PRs."
    Assert-True ($workflow -match "Post-repair Check") "Workflow should run a mandatory post-repair Check."
    Assert-True ($workflow -notmatch "secrets\.PAT" -and $workflow -notmatch "APP_TOKEN") "Workflow should not use PAT or GitHub App token in v1."
}

Write-Host ""
Write-Host "Doc metadata acceptance tests: $script:Passed passed, $script:Failed failed"

if ($script:Failed -gt 0) {
    exit 1
}
