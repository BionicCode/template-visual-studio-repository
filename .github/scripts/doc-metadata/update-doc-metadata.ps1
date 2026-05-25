#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Bootstrap", "Update", "Check")]
    [string] $Mode,

    [string] $Root,

    [string] $ManifestPath = ".github/doc-metadata/doc-metadata-manifest.json",

    [string[]] $Include = @(),

    [string[]] $Path = @(),

    [string] $EventName,

    [string] $EventPayloadPath,

    [string] $HeadSha,

    [string] $BaseSha,

    [string] $ChangedFilesOutputPath,

    [string] $ReportOutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RepositoryRoot = $null
$script:ManifestFullPath = $null
$script:ManagedFields = @("doc_version", "created", "updated")
$script:TimestampPattern = "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?[+-]\d{2}:\d{2}$"
$script:RemediationCommand = "pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root ."

function New-Report {
    param(
        [string] $ModeValue,
        [string] $RootValue,
        [string] $ManifestValue
    )

    @{
        mode = $ModeValue
        root = $RootValue
        manifestPath = $ManifestValue
        comparison = @{
            mode = $null
            baseSha = $null
            headSha = $null
            staleCheckAvailable = $false
            reason = $null
        }
        updatedFiles = [System.Collections.Generic.List[object]]::new()
        unchangedFiles = [System.Collections.Generic.List[object]]::new()
        skippedFiles = [System.Collections.Generic.List[object]]::new()
        failedFiles = [System.Collections.Generic.List[object]]::new()
        staleCheckSkippedFiles = [System.Collections.Generic.List[object]]::new()
        summaryCounts = @{}
    }
}

function Add-UpdatedFile {
    param(
        [hashtable] $Report,
        [string] $Path,
        [string] $Format,
        [string] $Placement,
        [object] $OldVersion,
        [object] $NewVersion,
        [object] $OldCreated,
        [object] $NewCreated,
        [object] $OldUpdated,
        [object] $NewUpdated,
        [string] $Reason
    )

    $Report.updatedFiles.Add([ordered]@{
        path = $Path
        metadataFormat = $Format
        metadataPlacement = $Placement
        oldDocVersion = $OldVersion
        newDocVersion = $NewVersion
        oldCreated = $OldCreated
        newCreated = $NewCreated
        oldUpdated = $OldUpdated
        newUpdated = $NewUpdated
        reason = $Reason
    })
}

function Add-UnchangedFile {
    param(
        [hashtable] $Report,
        [string] $Path,
        [string] $Reason,
        [object] $OldVersion = $null,
        [object] $NewVersion = $null
    )

    $Report.unchangedFiles.Add([ordered]@{
        path = $Path
        reason = $Reason
        oldDocVersion = $OldVersion
        newDocVersion = $NewVersion
    })
}

function Add-SkippedFile {
    param(
        [hashtable] $Report,
        [string] $Path,
        [string] $Reason
    )

    $Report.skippedFiles.Add([ordered]@{
        path = $Path
        reason = $Reason
    })
}

function Add-FailedFile {
    param(
        [hashtable] $Report,
        [string] $Path,
        [string] $Rule,
        [object] $Current,
        [string] $Expected,
        [string] $Remediation = $script:RemediationCommand
    )

    $Report.failedFiles.Add([ordered]@{
        path = $Path
        rule = $Rule
        current = $Current
        expected = $Expected
        remediation = $Remediation
    })
}

function Add-StaleSkippedFile {
    param(
        [hashtable] $Report,
        [string] $Path,
        [string] $Reason
    )

    $Report.staleCheckSkippedFiles.Add([ordered]@{
        path = $Path
        reason = $Reason
    })
}

function Get-PropertyValue {
    param(
        [object] $Object,
        [string] $Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    $property.Value
}

function Get-ObjectPropertyNames {
    param([object] $Object)

    if ($null -eq $Object) {
        return @()
    }

    @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-JsonArrayProperty {
    param(
        [object] $Object,
        [string] $Name
    )

    $value = Get-PropertyValue -Object $Object -Name $Name
    if ($null -eq $value) {
        return @()
    }

    if ($value -is [array]) {
        foreach ($item in $value) {
            $item
        }
        return
    }

    $value
}

function Get-NonNullValues {
    param([object[]] $Values)

    @($Values | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string] $_) })
}

function Resolve-RootPath {
    param([string] $RequestedRoot)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if ([System.IO.Path]::IsPathFullyQualified($RequestedRoot)) {
            return [System.IO.Path]::GetFullPath($RequestedRoot)
        }

        return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $RequestedRoot))
    }

    try {
        $gitRoot = (& git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return [System.IO.Path]::GetFullPath($gitRoot.Trim())
        }
    }
    catch {
        Write-Verbose "Git root detection failed: $($_.Exception.Message)"
    }

    [System.IO.Path]::GetFullPath((Get-Location).Path)
}

function Resolve-InRootPath {
    param(
        [string] $RootPath,
        [string] $InputPath
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($InputPath)) {
        [System.IO.Path]::GetFullPath($InputPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $RootPath $InputPath))
    }

    $rootWithSeparator = $RootPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }

    if ($candidate.Equals($RootPath, $comparison) -or $candidate.StartsWith($rootWithSeparator, $comparison)) {
        return $candidate
    }

    $null
}

function ConvertTo-RepoRelativePath {
    param(
        [string] $RootPath,
        [string] $FullPath
    )

    [System.IO.Path]::GetRelativePath($RootPath, $FullPath).Replace("\", "/")
}

function Normalize-RepoPath {
    param([string] $PathValue)

    $normalized = $PathValue.Replace("\", "/")
    while ($normalized.StartsWith("./", [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }

    $normalized.TrimStart("/")
}

function Convert-GlobToRegex {
    param([string] $Pattern)

    $patternValue = Normalize-RepoPath $Pattern
    if ($patternValue.EndsWith("/", [System.StringComparison]::Ordinal)) {
        $patternValue += "**"
    }

    $builder = [System.Text.StringBuilder]::new()
    [void] $builder.Append("^")
    $index = 0
    while ($index -lt $patternValue.Length) {
        $character = $patternValue[$index]
        if ($character -eq "*") {
            if (($index + 1) -lt $patternValue.Length -and $patternValue[$index + 1] -eq "*") {
                if (($index + 2) -lt $patternValue.Length -and $patternValue[$index + 2] -eq "/") {
                    [void] $builder.Append("(?:.*/)?")
                    $index += 3
                }
                else {
                    [void] $builder.Append(".*")
                    $index += 2
                }
            }
            else {
                [void] $builder.Append("[^/]*")
                $index++
            }
        }
        elseif ($character -eq "?") {
            [void] $builder.Append("[^/]")
            $index++
        }
        else {
            [void] $builder.Append([regex]::Escape([string] $character))
            $index++
        }
    }

    [void] $builder.Append("$")
    $builder.ToString()
}

function Test-GlobMatch {
    param(
        [string] $Pattern,
        [string] $PathValue
    )

    $normalizedPattern = Normalize-RepoPath $Pattern
    $normalizedPath = Normalize-RepoPath $PathValue

    if ($normalizedPattern.IndexOfAny([char[]]@("*", "?")) -lt 0) {
        if ($normalizedPattern.EndsWith("/", [System.StringComparison]::Ordinal)) {
            return $normalizedPath.StartsWith($normalizedPattern, [System.StringComparison]::Ordinal)
        }

        return $normalizedPath.Equals($normalizedPattern, [System.StringComparison]::Ordinal)
    }

    $regex = [regex]::new((Convert-GlobToRegex $normalizedPattern), [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $regex.IsMatch($normalizedPath)
}

function Test-AnyPatternMatch {
    param(
        [string[]] $Patterns,
        [string] $PathValue
    )

    foreach ($pattern in $Patterns) {
        if (Test-GlobMatch -Pattern $pattern -PathValue $PathValue) {
            return $true
        }
    }

    $false
}

function Get-PatternList {
    param([object[]] $Entries)

    $patterns = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry -is [string]) {
            $patterns.Add((Normalize-RepoPath $entry))
            continue
        }

        $pattern = Get-PropertyValue -Object $entry -Name "pattern"
        if ($pattern -is [string]) {
            $patterns.Add((Normalize-RepoPath $pattern))
        }
    }

    $patterns.ToArray()
}

function New-MetadataConfig {
    param(
        [object] $Defaults,
        [object] $Override = $null
    )

    $config = [ordered]@{
        metadataFormat = [string] (Get-PropertyValue -Object $Defaults -Name "metadataFormat")
        metadataPlacement = [string] (Get-PropertyValue -Object $Defaults -Name "metadataPlacement")
        versionField = [string] (Get-PropertyValue -Object $Defaults -Name "versionField")
        createdField = [string] (Get-PropertyValue -Object $Defaults -Name "createdField")
        updatedField = [string] (Get-PropertyValue -Object $Defaults -Name "updatedField")
        versioningMode = [string] (Get-PropertyValue -Object $Defaults -Name "versioningMode")
        timestampFormat = [string] (Get-PropertyValue -Object $Defaults -Name "timestampFormat")
        commentStart = $null
        commentLinePrefix = $null
        commentEnd = $null
    }

    if ($null -ne $Override) {
        foreach ($name in @("metadataFormat", "metadataPlacement", "versionField", "createdField", "updatedField", "versioningMode", "timestampFormat", "commentStart", "commentLinePrefix", "commentEnd")) {
            $value = Get-PropertyValue -Object $Override -Name $name
            if ($null -ne $value) {
                $config[$name] = [string] $value
            }
        }
    }

    [pscustomobject] $config
}

function Test-IsTimestamp {
    param([object] $Value)

    if ($Value -isnot [string]) {
        return $false
    }

    if ($Value -notmatch $script:TimestampPattern) {
        return $false
    }

    $parsed = [System.DateTimeOffset]::MinValue
    [System.DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref] $parsed)
}

function ConvertTo-TimestampValue {
    [System.DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:sszzz", [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-DisplayValue {
    param([object] $Value)

    if ($null -eq $Value -or $Value -eq "") {
        return "missing"
    }

    [string] $Value
}

function ConvertTo-NullableInt64 {
    param([object] $Value)

    if ($Value -is [int] -or $Value -is [long]) {
        if ([int64] $Value -gt 0) {
            return [int64] $Value
        }
    }

    if ($Value -is [string] -and $Value -match "^[1-9][0-9]*$") {
        return [int64] $Value
    }

    $null
}

function Split-ContentLines {
    param([string] $Content)

    $lines = [System.Collections.Generic.List[object]]::new()
    $index = 0
    while ($index -lt $Content.Length) {
        $lineStart = $index
        while ($index -lt $Content.Length -and $Content[$index] -ne "`r" -and $Content[$index] -ne "`n") {
            $index++
        }

        $text = $Content.Substring($lineStart, $index - $lineStart)
        $newLine = ""
        if ($index -lt $Content.Length) {
            if ($Content[$index] -eq "`r" -and ($index + 1) -lt $Content.Length -and $Content[$index + 1] -eq "`n") {
                $newLine = "`r`n"
                $index += 2
            }
            else {
                $newLine = [string] $Content[$index]
                $index++
            }
        }

        $lines.Add([pscustomobject]@{
            Text = $text
            NewLine = $newLine
        })
    }

    $lines.ToArray()
}

function Join-ContentLines {
    param([object[]] $Lines)

    $builder = [System.Text.StringBuilder]::new()
    foreach ($line in @($Lines)) {
        [void] $builder.Append($line.Text)
        [void] $builder.Append($line.NewLine)
    }

    $builder.ToString()
}

function Get-PreferredNewLine {
    param([string] $Content)

    $crlf = $Content.IndexOf("`r`n", [System.StringComparison]::Ordinal)
    if ($crlf -ge 0) {
        return "`r`n"
    }

    $lf = $Content.IndexOf("`n", [System.StringComparison]::Ordinal)
    if ($lf -ge 0) {
        return "`n"
    }

    $cr = $Content.IndexOf("`r", [System.StringComparison]::Ordinal)
    if ($cr -ge 0) {
        return "`r"
    }

    "`n"
}

function Read-StrictUtf8Text {
    param([string] $FullPath)

    $bytes = [System.IO.File]::ReadAllBytes($FullPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $length = $bytes.Length - $offset
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $content = $encoding.GetString($bytes, $offset, $length)

    [pscustomobject]@{
        Content = $content
        HasBom = $hasBom
        NewLine = Get-PreferredNewLine $content
    }
}

function Convert-StrictUtf8BytesToText {
    param([byte[]] $Bytes)

    $hasBom = $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $length = $Bytes.Length - $offset
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $encoding.GetString($Bytes, $offset, $length)
}

function Write-StrictUtf8Text {
    param(
        [string] $FullPath,
        [string] $Content,
        [bool] $HasBom
    )

    $encoding = [System.Text.UTF8Encoding]::new($HasBom)
    [System.IO.File]::WriteAllText($FullPath, $Content, $encoding)
}

function Invoke-GitRaw {
    param([string[]] $Arguments)

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = "git"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void] $processStartInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::Start($processStartInfo)
    $output = [System.IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($output)
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Bytes = $output.ToArray()
        Error = $errorText
    }
}

function Invoke-GitText {
    param([string[]] $Arguments)

    $result = Invoke-GitRaw -Arguments $Arguments
    $text = ""
    if ($result.Bytes.Length -gt 0) {
        $text = Convert-StrictUtf8BytesToText -Bytes $result.Bytes
    }

    [pscustomobject]@{
        ExitCode = $result.ExitCode
        Text = $text
        Error = $result.Error
    }
}

function Test-InGitRepository {
    $result = Invoke-GitText -Arguments @("-C", $script:RepositoryRoot, "rev-parse", "--is-inside-work-tree")
    $result.ExitCode -eq 0 -and $result.Text.Trim() -eq "true"
}

function Test-GitCommitExists {
    param([string] $Sha)

    if ([string]::IsNullOrWhiteSpace($Sha)) {
        return $false
    }

    $result = Invoke-GitText -Arguments @("-C", $script:RepositoryRoot, "cat-file", "-e", "$Sha^{commit}")
    $result.ExitCode -eq 0
}

function Get-GitFileContent {
    param(
        [string] $Revision,
        [string] $RepoPath
    )

    if ([string]::IsNullOrWhiteSpace($Revision) -or [string]::IsNullOrWhiteSpace($RepoPath)) {
        return $null
    }

    $result = Invoke-GitRaw -Arguments @("-C", $script:RepositoryRoot, "show", "$Revision`:$RepoPath")
    if ($result.ExitCode -ne 0) {
        return $null
    }

    try {
        Convert-StrictUtf8BytesToText -Bytes $result.Bytes
    }
    catch {
        $null
    }
}

function Get-GitMergeBase {
    param(
        [string] $Base,
        [string] $Head
    )

    $result = Invoke-GitText -Arguments @("-C", $script:RepositoryRoot, "merge-base", $Base, $Head)
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $result.Text.Trim()
}

function Parse-GitNameStatusZ {
    param([string] $Text)

    $tokens = @($Text -split "`0" | Where-Object { $_ -ne "" })
    $records = [System.Collections.Generic.List[object]]::new()
    $index = 0
    while ($index -lt $tokens.Count) {
        $status = $tokens[$index]
        $index++
        if ($status.StartsWith("R", [System.StringComparison]::Ordinal) -or $status.StartsWith("C", [System.StringComparison]::Ordinal)) {
            if (($index + 1) -ge $tokens.Count) {
                break
            }

            $oldPath = Normalize-RepoPath $tokens[$index]
            $newPath = Normalize-RepoPath $tokens[$index + 1]
            $index += 2
            $records.Add([pscustomobject]@{
                Status = $status
                Path = $newPath
                PreviousPath = $oldPath
            })
        }
        else {
            if ($index -ge $tokens.Count) {
                break
            }

            $pathValue = Normalize-RepoPath $tokens[$index]
            $index++
            $records.Add([pscustomobject]@{
                Status = $status
                Path = $pathValue
                PreviousPath = $pathValue
            })
        }
    }

    $records.ToArray()
}

function Get-UpdateCandidateRecords {
    $records = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-InGitRepository)) {
        return $records.ToArray()
    }

    $staged = Invoke-GitRaw -Arguments @("-C", $script:RepositoryRoot, "diff", "--cached", "--name-status", "--diff-filter=ACMR", "-z")
    if ($staged.ExitCode -eq 0 -and $staged.Bytes.Length -gt 0) {
        $text = Convert-StrictUtf8BytesToText -Bytes $staged.Bytes
        return @(Parse-GitNameStatusZ -Text $text)
    }

    $working = Invoke-GitRaw -Arguments @("-C", $script:RepositoryRoot, "diff", "--name-status", "--diff-filter=ACMR", "-z", "HEAD", "--")
    if ($working.ExitCode -eq 0 -and $working.Bytes.Length -gt 0) {
        $text = Convert-StrictUtf8BytesToText -Bytes $working.Bytes
        foreach ($record in @(Parse-GitNameStatusZ -Text $text)) {
            $records.Add($record)
        }
    }

    $untracked = Invoke-GitRaw -Arguments @("-C", $script:RepositoryRoot, "ls-files", "--others", "--exclude-standard", "-z")
    if ($untracked.ExitCode -eq 0 -and $untracked.Bytes.Length -gt 0) {
        $text = Convert-StrictUtf8BytesToText -Bytes $untracked.Bytes
        foreach ($pathValue in @($text -split "`0" | Where-Object { $_ -ne "" })) {
            $normalized = Normalize-RepoPath $pathValue
            $records.Add([pscustomobject]@{
                Status = "A"
                Path = $normalized
                PreviousPath = $normalized
            })
        }
    }

    $records.ToArray()
}

function Get-AllRepositoryFiles {
    if (Test-InGitRepository) {
        $files = Invoke-GitRaw -Arguments @("-C", $script:RepositoryRoot, "ls-files", "--cached", "--others", "--exclude-standard", "-z")
        if ($files.ExitCode -eq 0) {
            $text = Convert-StrictUtf8BytesToText -Bytes $files.Bytes
            return @($text -split "`0" | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-RepoPath $_ })
        }
    }

    Get-ChildItem -LiteralPath $script:RepositoryRoot -Recurse -File -Force |
        ForEach-Object { ConvertTo-RepoRelativePath -RootPath $script:RepositoryRoot -FullPath $_.FullName } |
        Where-Object { -not (Test-GlobMatch -Pattern ".git/**" -PathValue $_) }
}

function Test-PathIsReparsePoint {
    param([string] $FullPath)

    $item = Get-Item -LiteralPath $FullPath -Force
    ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Validate-PatternEntries {
    param(
        [object[]] $Entries,
        [string] $PathName
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry -is [string]) {
            if ([string]::IsNullOrWhiteSpace($entry)) {
                $errors.Add("$PathName entries must not be empty.")
            }
            continue
        }

        $pattern = Get-PropertyValue -Object $entry -Name "pattern"
        if ([string]::IsNullOrWhiteSpace([string] $pattern)) {
            $errors.Add("$PathName object entries must define a non-empty pattern property.")
        }
    }

    $errors.ToArray()
}

function Add-ValidationErrors {
    param(
        [System.Collections.Generic.List[string]] $Errors,
        [object[]] $AdditionalErrors
    )

    foreach ($additionalError in @($AdditionalErrors)) {
        if ($null -ne $additionalError) {
            $Errors.Add([string] $additionalError)
        }
    }
}

function Validate-MetadataConfig {
    param(
        [object] $Config,
        [string] $PathName,
        [bool] $RequireAll,
        [bool] $AllowPatternProperties = $false
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $allowedProperties = @("metadataFormat", "metadataPlacement", "versionField", "createdField", "updatedField", "versioningMode", "timestampFormat", "commentStart", "commentLinePrefix", "commentEnd")
    if ($AllowPatternProperties) {
        $allowedProperties += @("include", "exclude")
    }
    $required = @("metadataFormat", "metadataPlacement", "versionField", "createdField", "updatedField", "versioningMode", "timestampFormat")

    foreach ($propertyName in Get-ObjectPropertyNames $Config) {
        if ($propertyName -notin $allowedProperties) {
            $errors.Add("$PathName has unknown property '$propertyName'.")
        }
    }

    if ($RequireAll) {
        foreach ($requiredProperty in $required) {
            if ([string]::IsNullOrWhiteSpace([string] (Get-PropertyValue -Object $Config -Name $requiredProperty))) {
                $errors.Add("$PathName must define '$requiredProperty'.")
            }
        }
    }

    $format = Get-PropertyValue -Object $Config -Name "metadataFormat"
    $placement = Get-PropertyValue -Object $Config -Name "metadataPlacement"
    $versioningMode = Get-PropertyValue -Object $Config -Name "versioningMode"
    $timestampFormat = Get-PropertyValue -Object $Config -Name "timestampFormat"

    if ($null -ne $format -and $format -notin @("yaml-front-matter", "comment-block")) {
        $errors.Add("$PathName.metadataFormat must be 'yaml-front-matter' or 'comment-block'.")
    }

    if ($null -ne $placement -and $placement -notin @("top", "bottom")) {
        $errors.Add("$PathName.metadataPlacement must be 'top' or 'bottom'.")
    }

    if ($format -eq "yaml-front-matter" -and $placement -eq "bottom") {
        $errors.Add("$PathName cannot use metadataPlacement 'bottom' with yaml-front-matter.")
    }

    if ($null -ne $versioningMode -and $versioningMode -ne "body-content-change") {
        $errors.Add("$PathName.versioningMode must be 'body-content-change'.")
    }

    if ($null -ne $timestampFormat -and $timestampFormat -ne "iso-8601-offset") {
        $errors.Add("$PathName.timestampFormat must be 'iso-8601-offset'.")
    }

    $errors.ToArray()
}

function Read-Manifest {
    param([string] $ManifestFile)

    if (-not (Test-Path -LiteralPath $ManifestFile -PathType Leaf)) {
        throw "Manifest not found at '$ManifestFile'."
    }

    $manifestText = Get-Content -LiteralPath $ManifestFile -Raw
    $manifest = $manifestText | ConvertFrom-Json -Depth 32
    $errors = [System.Collections.Generic.List[string]]::new()
    $allowedTopLevel = @('$schema', "version", "defaults", "include", "exclude", "overrides")
    foreach ($propertyName in Get-ObjectPropertyNames $manifest) {
        if ($propertyName -notin $allowedTopLevel) {
            $errors.Add("Manifest has unknown top-level property '$propertyName'.")
        }
    }

    foreach ($requiredProperty in @('$schema', "version", "defaults", "include", "exclude")) {
        if ($null -eq (Get-PropertyValue -Object $manifest -Name $requiredProperty)) {
            $errors.Add("Manifest must define '$requiredProperty'.")
        }
    }

    if ((Get-PropertyValue -Object $manifest -Name "version") -ne 1) {
        $errors.Add("Manifest version must be integer 1.")
    }

    $defaults = Get-PropertyValue -Object $manifest -Name "defaults"
    Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-MetadataConfig -Config $defaults -PathName "defaults" -RequireAll $true)

    [object[]] $includeEntries = @(Get-JsonArrayProperty -Object $manifest -Name "include")
    [object[]] $excludeEntries = @(Get-JsonArrayProperty -Object $manifest -Name "exclude")
    Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-PatternEntries -Entries $includeEntries -PathName "include")
    Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-PatternEntries -Entries $excludeEntries -PathName "exclude")

    [object[]] $overrides = @(Get-JsonArrayProperty -Object $manifest -Name "overrides")
    for ($overrideIndex = 0; $overrideIndex -lt $overrides.Count; $overrideIndex++) {
        $override = $overrides[$overrideIndex]
        foreach ($propertyName in Get-ObjectPropertyNames $override) {
            if ($propertyName -notin @("include", "exclude", "metadataFormat", "metadataPlacement", "versionField", "createdField", "updatedField", "versioningMode", "timestampFormat", "commentStart", "commentLinePrefix", "commentEnd")) {
                $errors.Add("overrides[$overrideIndex] has unknown property '$propertyName'.")
            }
        }

        Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-MetadataConfig -Config $override -PathName "overrides[$overrideIndex]" -RequireAll $false -AllowPatternProperties $true)
        $overrideFormat = Get-PropertyValue -Object $override -Name "metadataFormat"
        if ($overrideFormat -eq "comment-block") {
            if ([string]::IsNullOrWhiteSpace([string] (Get-PropertyValue -Object $override -Name "commentStart"))) {
                $errors.Add("overrides[$overrideIndex].commentStart is required for comment-block metadata.")
            }

            if ([string]::IsNullOrWhiteSpace([string] (Get-PropertyValue -Object $override -Name "commentEnd"))) {
                $errors.Add("overrides[$overrideIndex].commentEnd is required for comment-block metadata.")
            }
        }

        [object[]] $overrideInclude = @(Get-JsonArrayProperty -Object $override -Name "include")
        [object[]] $overrideExclude = @(Get-JsonArrayProperty -Object $override -Name "exclude")
        if ($overrideInclude.Count -gt 0) {
            Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-PatternEntries -Entries $overrideInclude -PathName "overrides[$overrideIndex].include")
        }
        if ($overrideExclude.Count -gt 0) {
            Add-ValidationErrors -Errors $errors -AdditionalErrors (Validate-PatternEntries -Entries $overrideExclude -PathName "overrides[$overrideIndex].exclude")
        }
    }

    if ($errors.Count -gt 0) {
        throw "Invalid document metadata manifest:`n$($errors -join "`n")"
    }

    $manifest
}

function Resolve-GovernedFiles {
    param(
        [object] $Manifest,
        [string[]] $BootstrapIncludePatterns = @()
    )

    $files = Get-AllRepositoryFiles
    [object[]] $bootstrapIncludeValues = @(Get-NonNullValues -Values $BootstrapIncludePatterns)
    $defaultIncludeEntries = if ($bootstrapIncludeValues.Length -gt 0) { $bootstrapIncludeValues } else { @(Get-JsonArrayProperty -Object $Manifest -Name "include") }
    $defaultIncludePatterns = Get-PatternList -Entries $defaultIncludeEntries
    $topExcludePatterns = Get-PatternList -Entries @(Get-JsonArrayProperty -Object $Manifest -Name "exclude")
    $defaults = Get-PropertyValue -Object $Manifest -Name "defaults"
    [object[]] $overrides = @(Get-JsonArrayProperty -Object $Manifest -Name "overrides")
    $governed = @{}

    Write-Verbose "Resolved $(@($files).Count) repository files."
    Write-Verbose "Default include patterns: $($defaultIncludePatterns -join ', ')"
    Write-Verbose "Default exclude patterns: $($topExcludePatterns -join ', ')"

    foreach ($repoPath in $files) {
        if (Test-AnyPatternMatch -Patterns $topExcludePatterns -PathValue $repoPath) {
            continue
        }

        $config = $null
        if (Test-AnyPatternMatch -Patterns $defaultIncludePatterns -PathValue $repoPath) {
            $config = New-MetadataConfig -Defaults $defaults
        }

        foreach ($override in $overrides) {
            $overrideInclude = Get-PatternList -Entries @(Get-JsonArrayProperty -Object $override -Name "include")
            if (@($overrideInclude).Count -eq 0 -or -not (Test-AnyPatternMatch -Patterns @($overrideInclude) -PathValue $repoPath)) {
                continue
            }

            $overrideExclude = Get-PatternList -Entries @(Get-JsonArrayProperty -Object $override -Name "exclude")
            if (@($overrideExclude).Count -gt 0 -and (Test-AnyPatternMatch -Patterns @($overrideExclude) -PathValue $repoPath)) {
                continue
            }

            $config = New-MetadataConfig -Defaults $defaults -Override $override
        }

        if ($null -ne $config) {
            Write-Verbose "Governed file: $repoPath"
            $governed[$repoPath] = [pscustomobject]@{
                Path = $repoPath
                FullPath = Join-Path $script:RepositoryRoot ($repoPath.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
                Config = $config
            }
        }
    }

    $governed
}

function Test-ManifestExcludedPath {
    param(
        [object] $Manifest,
        [string] $RepoPath
    )

    $excludePatterns = Get-PatternList -Entries @(Get-JsonArrayProperty -Object $Manifest -Name "exclude")
    Test-AnyPatternMatch -Patterns $excludePatterns -PathValue $RepoPath
}

function Get-YamlMetadataInfo {
    param([string] $Content)

    $lines = Split-ContentLines $Content
    if ($lines.Count -eq 0 -or $lines[0].Text -ne "---") {
        return [pscustomobject]@{
            HasMetadata = $false
            IsMalformed = $false
            Fields = @{}
            Body = $Content
            MetadataLines = @()
        }
    }

    $closingIndex = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Text -eq "---") {
            $closingIndex = $index
            break
        }
    }

    if ($closingIndex -lt 0) {
        return [pscustomobject]@{
            HasMetadata = $true
            IsMalformed = $true
            Fields = @{}
            Body = $Content
            MetadataLines = @()
        }
    }

    $metadataLines = if ($closingIndex -gt 1) { @($lines[1..($closingIndex - 1)] | ForEach-Object { $_.Text }) } else { @() }
    $bodyLines = if (($closingIndex + 1) -lt $lines.Count) { @($lines[($closingIndex + 1)..($lines.Count - 1)]) } else { @() }
    $fields = Get-SimpleMetadataFields -MetadataLines $metadataLines

    [pscustomobject]@{
        HasMetadata = $true
        IsMalformed = $false
        Fields = $fields
        Body = (Join-ContentLines $bodyLines)
        MetadataLines = $metadataLines
    }
}

function Get-CommentMetadataInfo {
    param(
        [string] $Content,
        [object] $Config
    )

    $lines = Split-ContentLines $Content
    $start = [string] $Config.commentStart
    $end = [string] $Config.commentEnd
    if ($lines.Count -eq 0) {
        return [pscustomobject]@{
            HasMetadata = $false
            IsMalformed = $false
            Fields = @{}
            Body = $Content
            MetadataLines = @()
        }
    }

    if ($Config.metadataPlacement -eq "top") {
        if ($lines[0].Text.TrimEnd() -ne $start) {
            return [pscustomobject]@{
                HasMetadata = $false
                IsMalformed = $false
                Fields = @{}
                Body = $Content
                MetadataLines = @()
            }
        }

        $closingIndex = -1
        for ($index = 1; $index -lt $lines.Count; $index++) {
            if ($lines[$index].Text.Trim() -eq $end) {
                $closingIndex = $index
                break
            }
        }

        if ($closingIndex -lt 0) {
            return [pscustomobject]@{
                HasMetadata = $true
                IsMalformed = $true
                Fields = @{}
                Body = $Content
                MetadataLines = @()
            }
        }

        $metadataLines = if ($closingIndex -gt 1) { @($lines[1..($closingIndex - 1)] | ForEach-Object { Remove-CommentLinePrefix -Line $_.Text -Prefix $Config.commentLinePrefix }) } else { @() }
        $bodyLines = if (($closingIndex + 1) -lt $lines.Count) { @($lines[($closingIndex + 1)..($lines.Count - 1)]) } else { @() }
        return [pscustomobject]@{
            HasMetadata = $true
            IsMalformed = $false
            Fields = (Get-SimpleMetadataFields -MetadataLines $metadataLines)
            Body = (Join-ContentLines $bodyLines)
            MetadataLines = $metadataLines
        }
    }

    $endIndex = -1
    for ($index = $lines.Count - 1; $index -ge 0; $index--) {
        if ($lines[$index].Text.Trim() -eq $end) {
            $endIndex = $index
            break
        }
        if (-not [string]::IsNullOrWhiteSpace($lines[$index].Text)) {
            break
        }
    }

    if ($endIndex -lt 0) {
        return [pscustomobject]@{
            HasMetadata = $false
            IsMalformed = $false
            Fields = @{}
            Body = $Content
            MetadataLines = @()
        }
    }

    $startIndex = -1
    for ($index = $endIndex - 1; $index -ge 0; $index--) {
        if ($lines[$index].Text.TrimEnd() -eq $start) {
            $startIndex = $index
            break
        }
    }

    if ($startIndex -lt 0) {
        return [pscustomobject]@{
            HasMetadata = $true
            IsMalformed = $true
            Fields = @{}
            Body = $Content
            MetadataLines = @()
        }
    }

    $metadataLines = if (($endIndex - $startIndex) -gt 1) { @($lines[($startIndex + 1)..($endIndex - 1)] | ForEach-Object { Remove-CommentLinePrefix -Line $_.Text -Prefix $Config.commentLinePrefix }) } else { @() }
    $bodyLines = if ($startIndex -gt 0) { @($lines[0..($startIndex - 1)]) } else { @() }

    [pscustomobject]@{
        HasMetadata = $true
        IsMalformed = $false
        Fields = (Get-SimpleMetadataFields -MetadataLines $metadataLines)
        Body = (Join-ContentLines $bodyLines)
        MetadataLines = $metadataLines
    }
}

function Remove-CommentLinePrefix {
    param(
        [string] $Line,
        [object] $Prefix
    )

    if ($null -eq $Prefix -or [string]::IsNullOrEmpty([string] $Prefix)) {
        return $Line
    }

    $prefixValue = [string] $Prefix
    if ($Line.StartsWith($prefixValue, [System.StringComparison]::Ordinal)) {
        return $Line.Substring($prefixValue.Length)
    }

    $Line
}

function Get-SimpleMetadataFields {
    param([string[]] $MetadataLines)

    $fields = @{}
    foreach ($line in @($MetadataLines)) {
        if ($line -match "^\s*([^:#][^:]*?)\s*:\s*(.*?)\s*$") {
            $fields[$matches[1]] = $matches[2]
        }
    }

    $fields
}

function Get-MetadataInfo {
    param(
        [string] $Content,
        [object] $Config
    )

    if ($Config.metadataFormat -eq "yaml-front-matter") {
        return Get-YamlMetadataInfo -Content $Content
    }

    Get-CommentMetadataInfo -Content $Content -Config $Config
}

function Update-MetadataLines {
    param(
        [string[]] $MetadataLines,
        [hashtable] $Values,
        [object] $Config
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @($MetadataLines)) {
        $lines.Add($line)
    }

    foreach ($fieldName in @($Config.versionField, $Config.createdField, $Config.updatedField)) {
        $found = $false
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -match "^\s*$([regex]::Escape($fieldName))\s*:") {
                $lines[$index] = "${fieldName}: $($Values[$fieldName])"
                $found = $true
                break
            }
        }

        if (-not $found) {
            $lines.Add("${fieldName}: $($Values[$fieldName])")
        }
    }

    $lines.ToArray()
}

function New-MetadataBlock {
    param(
        [string[]] $Lines,
        [object] $Config,
        [string] $NewLine
    )

    if ($Config.metadataFormat -eq "yaml-front-matter") {
        return "---$NewLine$($Lines -join $NewLine)$NewLine---$NewLine"
    }

    $prefix = if ($null -ne $Config.commentLinePrefix) { [string] $Config.commentLinePrefix } else { "" }
    $prefixed = @($Lines | ForEach-Object { "$prefix$_" })
    "$($Config.commentStart)$NewLine$($prefixed -join $NewLine)$NewLine$($Config.commentEnd)$NewLine"
}

function Set-MetadataContent {
    param(
        [string] $Content,
        [object] $Config,
        [hashtable] $Values,
        [string] $NewLine
    )

    $info = Get-MetadataInfo -Content $Content -Config $Config
    $metadataLines = if ($info.HasMetadata -and -not $info.IsMalformed) { @($info.MetadataLines) } else { @() }
    $updatedLines = Update-MetadataLines -MetadataLines $metadataLines -Values $Values -Config $Config
    $metadataBlock = New-MetadataBlock -Lines $updatedLines -Config $Config -NewLine $NewLine

    if ($Config.metadataFormat -eq "yaml-front-matter" -or $Config.metadataPlacement -eq "top") {
        return $metadataBlock + $info.Body
    }

    $body = $info.Body
    if ($body.Length -gt 0 -and -not ($body.EndsWith("`n", [System.StringComparison]::Ordinal) -or $body.EndsWith("`r", [System.StringComparison]::Ordinal))) {
        $body += $NewLine
    }

    $body + $metadataBlock
}

function Validate-FileMetadata {
    param(
        [object] $MetadataInfo,
        [object] $Config
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    if (-not $MetadataInfo.HasMetadata) {
        $errors.Add([pscustomobject]@{
            Rule = "metadata block exists"
            Current = "missing"
            Expected = "managed metadata block must be present"
        })
        return $errors.ToArray()
    }

    if ($MetadataInfo.IsMalformed) {
        $errors.Add([pscustomobject]@{
            Rule = "metadata block format"
            Current = "malformed"
            Expected = "metadata block must match manifest metadataFormat"
        })
        return $errors.ToArray()
    }

    $versionValue = if ($MetadataInfo.Fields.ContainsKey($Config.versionField)) { $MetadataInfo.Fields[$Config.versionField] } else { $null }
    $createdValue = if ($MetadataInfo.Fields.ContainsKey($Config.createdField)) { $MetadataInfo.Fields[$Config.createdField] } else { $null }
    $updatedValue = if ($MetadataInfo.Fields.ContainsKey($Config.updatedField)) { $MetadataInfo.Fields[$Config.updatedField] } else { $null }

    if ($null -eq (ConvertTo-NullableInt64 $versionValue)) {
        $errors.Add([pscustomobject]@{
            Rule = $Config.versionField
            Current = $versionValue
            Expected = "positive integer document revision"
        })
    }

    if (-not (Test-IsTimestamp $createdValue)) {
        $errors.Add([pscustomobject]@{
            Rule = $Config.createdField
            Current = $createdValue
            Expected = "ISO-8601 timestamp with timezone offset"
        })
    }

    if (-not (Test-IsTimestamp $updatedValue)) {
        $errors.Add([pscustomobject]@{
            Rule = $Config.updatedField
            Current = $updatedValue
            Expected = "ISO-8601 timestamp with timezone offset"
        })
    }

    $errors.ToArray()
}

function Get-MetadataSnapshot {
    param(
        [object] $MetadataInfo,
        [object] $Config
    )

    if (-not $MetadataInfo.HasMetadata -or $MetadataInfo.IsMalformed) {
        return [pscustomobject]@{
            Version = $null
            Created = $null
            Updated = $null
        }
    }

    [pscustomobject]@{
        Version = if ($MetadataInfo.Fields.ContainsKey($Config.versionField)) { ConvertTo-NullableInt64 $MetadataInfo.Fields[$Config.versionField] } else { $null }
        Created = if ($MetadataInfo.Fields.ContainsKey($Config.createdField)) { $MetadataInfo.Fields[$Config.createdField] } else { $null }
        Updated = if ($MetadataInfo.Fields.ContainsKey($Config.updatedField)) { $MetadataInfo.Fields[$Config.updatedField] } else { $null }
    }
}

function Get-ComparisonInfo {
    param(
        [string] $RequestedEventName,
        [string] $RequestedEventPayloadPath,
        [string] $RequestedHeadSha,
        [string] $RequestedBaseSha
    )

    $comparison = @{
        mode = "format-only fallback"
        baseSha = $null
        headSha = $null
        staleCheckAvailable = $false
        reason = "No reliable comparison base is available."
    }

    if (-not (Test-InGitRepository)) {
        $comparison.reason = "Not inside a Git repository."
        return $comparison
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedEventName)) {
        if ([string]::IsNullOrWhiteSpace($RequestedEventPayloadPath) -or -not (Test-Path -LiteralPath $RequestedEventPayloadPath -PathType Leaf)) {
            throw "Event data was provided for '$RequestedEventName', but EventPayloadPath is missing or unreadable."
        }

        $payload = Get-Content -LiteralPath $RequestedEventPayloadPath -Raw | ConvertFrom-Json -Depth 64
        if ($RequestedEventName -eq "pull_request") {
            $payloadBase = Get-PropertyValue -Object (Get-PropertyValue -Object (Get-PropertyValue -Object $payload -Name "pull_request") -Name "base") -Name "sha"
            $payloadHead = Get-PropertyValue -Object (Get-PropertyValue -Object (Get-PropertyValue -Object $payload -Name "pull_request") -Name "head") -Name "sha"
            $base = if (-not [string]::IsNullOrWhiteSpace($RequestedBaseSha)) { $RequestedBaseSha } else { $payloadBase }
            $head = $payloadHead

            if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($head)) {
                throw "pull_request event payload does not contain fetchable base/head SHAs."
            }
            if (-not (Test-GitCommitExists $base)) {
                throw "pull_request base SHA '$base' is not fetchable in the local checkout."
            }
            if (-not (Test-GitCommitExists $head)) {
                throw "pull_request head SHA '$head' is not fetchable in the local checkout."
            }

            $mergeBase = Get-GitMergeBase -Base $base -Head $head
            if ([string]::IsNullOrWhiteSpace($mergeBase)) {
                throw "Unable to compute git merge-base for pull_request base '$base' and head '$head'."
            }

            $comparison.mode = "pull_request"
            $comparison.baseSha = $mergeBase
            $comparison.headSha = $head
            $comparison.staleCheckAvailable = $true
            $comparison.reason = "Comparing pull request merge-base to PR head."
            return $comparison
        }

        if ($RequestedEventName -eq "push") {
            $before = Get-PropertyValue -Object $payload -Name "before"
            $after = Get-PropertyValue -Object $payload -Name "after"
            $head = if (-not [string]::IsNullOrWhiteSpace($RequestedHeadSha)) { $RequestedHeadSha } else { $after }
            if ([string]::IsNullOrWhiteSpace($head)) {
                throw "push event did not provide a head SHA."
            }
            if (-not (Test-GitCommitExists $head)) {
                throw "push head SHA '$head' is not fetchable in the local checkout."
            }

            $comparison.mode = "push"
            $comparison.headSha = $head
            if ($before -match "^0{40}$") {
                $comparison.baseSha = $null
                $comparison.staleCheckAvailable = $false
                $comparison.reason = "Push before SHA is all zero; governed files are treated as new for stale checks."
                return $comparison
            }

            if ([string]::IsNullOrWhiteSpace($before) -or -not (Test-GitCommitExists $before)) {
                throw "push before SHA '$before' is missing or not fetchable in the local checkout."
            }

            $comparison.baseSha = $before
            $comparison.staleCheckAvailable = $true
            $comparison.reason = "Comparing push before SHA to head SHA."
            return $comparison
        }

        $comparison.mode = "format-only fallback"
        $comparison.headSha = $RequestedHeadSha
        $comparison.reason = "Event '$RequestedEventName' has no reliable comparison base; stale checks skipped."
        return $comparison
    }

    $headResult = Invoke-GitText -Arguments @("-C", $script:RepositoryRoot, "rev-parse", "HEAD")
    $baseResult = Invoke-GitText -Arguments @("-C", $script:RepositoryRoot, "rev-parse", "HEAD^")
    if ($headResult.ExitCode -eq 0 -and $baseResult.ExitCode -eq 0) {
        $comparison.mode = "local"
        $comparison.baseSha = $baseResult.Text.Trim()
        $comparison.headSha = $headResult.Text.Trim()
        $comparison.staleCheckAvailable = $true
        $comparison.reason = "Comparing local HEAD^ to HEAD."
        return $comparison
    }

    $comparison
}

function Convert-ExplicitPathsToRecords {
    param(
        [string[]] $RequestedPaths,
        [hashtable] $Report
    )

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($requestedPath in @($RequestedPaths)) {
        $fullPath = Resolve-InRootPath -RootPath $script:RepositoryRoot -InputPath $requestedPath
        if ($null -eq $fullPath) {
            Add-SkippedFile -Report $Report -Path (Normalize-RepoPath $requestedPath) -Reason "outside repository root"
            continue
        }

        $repoPath = ConvertTo-RepoRelativePath -RootPath $script:RepositoryRoot -FullPath $fullPath
        $records.Add([pscustomobject]@{
            Status = "explicit"
            Path = $repoPath
            PreviousPath = $repoPath
        })
    }

    $records.ToArray()
}

function Get-SelectedGovernedRecords {
    param(
        [object] $Manifest,
        [hashtable] $GovernedFiles,
        [hashtable] $Report,
        [string] $ModeValue
    )

    [object[]] $requestedPathValues = @(Get-NonNullValues -Values $Path)
    if ($requestedPathValues.Length -gt 0) {
        $candidateRecords = Convert-ExplicitPathsToRecords -RequestedPaths $Path -Report $Report
    }
    elseif ($ModeValue -eq "Update") {
        $candidateRecords = Get-UpdateCandidateRecords
    }
    else {
        $candidateRecords = @($GovernedFiles.Values | ForEach-Object {
            [pscustomobject]@{
                Status = "governed"
                Path = $_.Path
                PreviousPath = $_.Path
            }
        })
    }

    $selected = [System.Collections.Generic.List[object]]::new()
    foreach ($record in @($candidateRecords)) {
        $repoPath = Normalize-RepoPath $record.Path
        if (-not $GovernedFiles.ContainsKey($repoPath)) {
            $reason = if (Test-ManifestExcludedPath -Manifest $Manifest -RepoPath $repoPath) { "excluded by manifest" } else { "not governed by manifest" }
            Add-SkippedFile -Report $Report -Path $repoPath -Reason $reason
            continue
        }

        $governed = $GovernedFiles[$repoPath]
        $selected.Add([pscustomobject]@{
            Path = $repoPath
            PreviousPath = Normalize-RepoPath $record.PreviousPath
            FullPath = $governed.FullPath
            Config = $governed.Config
        })
    }

    @($selected.ToArray() | Sort-Object -Property Path -Unique)
}

function Initialize-OrUpdateFile {
    param(
        [object] $Record,
        [hashtable] $Report,
        [string] $ModeValue
    )

    $repoPath = $Record.Path
    $config = $Record.Config

    if (-not (Test-Path -LiteralPath $Record.FullPath -PathType Leaf)) {
        Add-SkippedFile -Report $Report -Path $repoPath -Reason "deleted file"
        return
    }

    if (Test-PathIsReparsePoint -FullPath $Record.FullPath) {
        Add-SkippedFile -Report $Report -Path $repoPath -Reason "reparse point / symlink write blocked"
        return
    }

    try {
        $textFile = Read-StrictUtf8Text -FullPath $Record.FullPath
    }
    catch {
        Add-FailedFile -Report $Report -Path $repoPath -Rule "UTF-8" -Current "invalid UTF-8" -Expected "valid UTF-8 text" -Remediation "Convert the file to UTF-8 or exclude it from .github/doc-metadata/doc-metadata-manifest.json."
        return
    }

    $currentInfo = Get-MetadataInfo -Content $textFile.Content -Config $config
    $currentSnapshot = Get-MetadataSnapshot -MetadataInfo $currentInfo -Config $config
    $previousContent = Get-GitFileContent -Revision "HEAD" -RepoPath $Record.PreviousPath
    $previousInfo = if ($null -ne $previousContent) { Get-MetadataInfo -Content $previousContent -Config $config } else { $null }
    $previousSnapshot = if ($null -ne $previousInfo) { Get-MetadataSnapshot -MetadataInfo $previousInfo -Config $config } else { $null }

    $bodyChanged = if ($null -ne $previousInfo) { $currentInfo.Body -ne $previousInfo.Body } else { $false }
    $now = ConvertTo-TimestampValue

    if ($currentInfo.HasMetadata -and -not $currentInfo.IsMalformed) {
        [object[]] $metadataValidationErrors = @(Validate-FileMetadata -MetadataInfo $currentInfo -Config $config)
        [object[]] $invalidVersionErrors = @($metadataValidationErrors | Where-Object { $_.Rule -eq $config.versionField })
        if ($invalidVersionErrors.Count -gt 0) {
            foreach ($error in $invalidVersionErrors) {
                Add-FailedFile -Report $Report -Path $repoPath -Rule $error.Rule -Current $error.Current -Expected $error.Expected
            }
            return
        }
    }

    if ($null -ne $previousSnapshot -and $null -ne $previousSnapshot.Version -and $null -ne $currentSnapshot.Version -and $currentSnapshot.Version -lt $previousSnapshot.Version) {
        Add-FailedFile -Report $Report -Path $repoPath -Rule "doc_version must not decrease without explicit rebaseline approval" -Current $currentSnapshot.Version -Expected "greater than or equal to previous committed doc_version $($previousSnapshot.Version)"
        return
    }

    if (-not $currentInfo.HasMetadata -or $currentInfo.IsMalformed) {
        $values = @{
            $config.versionField = 1
            $config.createdField = $now
            $config.updatedField = $now
        }
        $newContent = Set-MetadataContent -Content $textFile.Content -Config $config -Values $values -NewLine $textFile.NewLine
        if ($PSCmdlet.ShouldProcess($repoPath, "Initialize document metadata")) {
            Write-StrictUtf8Text -FullPath $Record.FullPath -Content $newContent -HasBom $textFile.HasBom
        }
        Add-UpdatedFile -Report $Report -Path $repoPath -Format $config.metadataFormat -Placement $config.metadataPlacement -OldVersion $null -NewVersion 1 -OldCreated $null -NewCreated $now -OldUpdated $null -NewUpdated $now -Reason "missing metadata initialized"
        return
    }

    [object[]] $validationErrors = @(Validate-FileMetadata -MetadataInfo $currentInfo -Config $config)
    [object[]] $repairableErrors = @($validationErrors | Where-Object { $_.Rule -ne $config.versionField })
    if ($ModeValue -eq "Bootstrap" -and $validationErrors.Length -eq 0) {
        Add-UnchangedFile -Report $Report -Path $repoPath -Reason "metadata valid" -OldVersion $currentSnapshot.Version -NewVersion $currentSnapshot.Version
        return
    }

    if ($validationErrors.Count -gt 0 -and $repairableErrors.Count -ne $validationErrors.Count) {
        foreach ($error in $validationErrors) {
            Add-FailedFile -Report $Report -Path $repoPath -Rule $error.Rule -Current $error.Current -Expected $error.Expected
        }
        return
    }

    $newVersion = $currentSnapshot.Version
    $newCreated = $currentSnapshot.Created
    $newUpdated = $currentSnapshot.Updated
    $reason = $null
    $shouldWrite = $false

    if ($validationErrors.Count -gt 0) {
        if ($null -eq $newVersion) {
            $newVersion = 1
        }
        if (-not (Test-IsTimestamp $newCreated)) {
            $newCreated = $now
        }
        if (-not (Test-IsTimestamp $newUpdated)) {
            $newUpdated = $now
        }
        $reason = "metadata repaired"
        $shouldWrite = $true
    }
    elseif ($bodyChanged) {
        $newVersion = [int64] $currentSnapshot.Version + 1
        $newCreated = $currentSnapshot.Created
        $newUpdated = $now
        $reason = "body changed"
        $shouldWrite = $true
    }
    elseif ($null -ne $previousSnapshot -and $null -ne $previousSnapshot.Version -and $currentSnapshot.Version -gt $previousSnapshot.Version) {
        Add-UnchangedFile -Report $Report -Path $repoPath -Reason "manual version rebaseline" -OldVersion $previousSnapshot.Version -NewVersion $currentSnapshot.Version
        return
    }
    elseif ($null -ne $previousSnapshot -and (Test-IsTimestamp $previousSnapshot.Created) -and (Test-IsTimestamp $previousSnapshot.Updated) -and ($currentSnapshot.Created -ne $previousSnapshot.Created -or $currentSnapshot.Updated -ne $previousSnapshot.Updated)) {
        $newCreated = $previousSnapshot.Created
        $newUpdated = $previousSnapshot.Updated
        $reason = "metadata repaired"
        $shouldWrite = $true
    }
    else {
        $reason = if ($null -ne $previousInfo -and (($currentInfo.MetadataLines -join "`n") -ne ($previousInfo.MetadataLines -join "`n"))) { "metadata-only change" } else { "no body change" }
        $oldVersionForReport = if ($null -ne $previousSnapshot) { $previousSnapshot.Version } else { $null }
        Add-UnchangedFile -Report $Report -Path $repoPath -Reason $reason -OldVersion $oldVersionForReport -NewVersion $currentSnapshot.Version
        return
    }

    if ($shouldWrite) {
        $values = @{
            $config.versionField = $newVersion
            $config.createdField = $newCreated
            $config.updatedField = $newUpdated
        }
        $newContent = Set-MetadataContent -Content $textFile.Content -Config $config -Values $values -NewLine $textFile.NewLine
        if ($PSCmdlet.ShouldProcess($repoPath, "Update document metadata")) {
            Write-StrictUtf8Text -FullPath $Record.FullPath -Content $newContent -HasBom $textFile.HasBom
        }
        Add-UpdatedFile -Report $Report -Path $repoPath -Format $config.metadataFormat -Placement $config.metadataPlacement -OldVersion $currentSnapshot.Version -NewVersion $newVersion -OldCreated $currentSnapshot.Created -NewCreated $newCreated -OldUpdated $currentSnapshot.Updated -NewUpdated $newUpdated -Reason $reason
    }
}

function Test-GovernedFile {
    param(
        [object] $Record,
        [hashtable] $Report,
        [hashtable] $Comparison
    )

    $repoPath = $Record.Path
    $config = $Record.Config
    if (-not (Test-Path -LiteralPath $Record.FullPath -PathType Leaf)) {
        Add-SkippedFile -Report $Report -Path $repoPath -Reason "deleted file"
        return
    }

    try {
        $textFile = Read-StrictUtf8Text -FullPath $Record.FullPath
    }
    catch {
        Add-FailedFile -Report $Report -Path $repoPath -Rule "UTF-8" -Current "invalid UTF-8" -Expected "valid UTF-8 text" -Remediation "Convert the file to UTF-8 or exclude it from .github/doc-metadata/doc-metadata-manifest.json."
        return
    }

    $currentInfo = Get-MetadataInfo -Content $textFile.Content -Config $config
    [object[]] $errors = @(Validate-FileMetadata -MetadataInfo $currentInfo -Config $config)
    foreach ($error in $errors) {
        Add-FailedFile -Report $Report -Path $repoPath -Rule $error.Rule -Current $error.Current -Expected $error.Expected
    }

    if ($errors.Length -gt 0) {
        return
    }

    $currentSnapshot = Get-MetadataSnapshot -MetadataInfo $currentInfo -Config $config
    if (-not $Comparison.staleCheckAvailable) {
        Add-StaleSkippedFile -Report $Report -Path $repoPath -Reason $Comparison.reason
        Add-UnchangedFile -Report $Report -Path $repoPath -Reason "metadata valid"
        return
    }

    $previousContent = Get-GitFileContent -Revision $Comparison.baseSha -RepoPath $repoPath
    if ($null -eq $previousContent) {
        Add-UnchangedFile -Report $Report -Path $repoPath -Reason "metadata valid; new governed file"
        return
    }

    $previousInfo = Get-MetadataInfo -Content $previousContent -Config $config
    $previousSnapshot = Get-MetadataSnapshot -MetadataInfo $previousInfo -Config $config
    if ($null -ne $previousSnapshot.Version -and $currentSnapshot.Version -lt $previousSnapshot.Version) {
        Add-FailedFile -Report $Report -Path $repoPath -Rule "doc_version must not decrease without explicit rebaseline approval" -Current $currentSnapshot.Version -Expected "greater than or equal to previous committed doc_version $($previousSnapshot.Version)"
        return
    }

    $bodyChanged = $currentInfo.Body -ne $previousInfo.Body
    if (-not $bodyChanged) {
        Add-StaleSkippedFile -Report $Report -Path $repoPath -Reason "no body change"
        if ($null -ne $previousSnapshot.Created -and $currentSnapshot.Created -ne $previousSnapshot.Created) {
            Add-FailedFile -Report $Report -Path $repoPath -Rule $config.createdField -Current $currentSnapshot.Created -Expected "unchanged when body content did not change"
            return
        }
        if ($null -ne $previousSnapshot.Updated -and $currentSnapshot.Updated -ne $previousSnapshot.Updated) {
            Add-FailedFile -Report $Report -Path $repoPath -Rule $config.updatedField -Current $currentSnapshot.Updated -Expected "unchanged when body content did not change"
            return
        }

        Add-UnchangedFile -Report $Report -Path $repoPath -Reason "metadata valid"
        return
    }

    if ($null -ne $previousSnapshot.Version -and $currentSnapshot.Version -le $previousSnapshot.Version) {
        Add-FailedFile -Report $Report -Path $repoPath -Rule $config.versionField -Current $currentSnapshot.Version -Expected "greater than previous doc_version $($previousSnapshot.Version) because body content changed"
        return
    }

    if ($null -ne $previousSnapshot.Updated) {
        $currentUpdated = [System.DateTimeOffset]::Parse($currentSnapshot.Updated, [System.Globalization.CultureInfo]::InvariantCulture)
        $previousUpdated = [System.DateTimeOffset]::Parse($previousSnapshot.Updated, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($currentUpdated -le $previousUpdated) {
            Add-FailedFile -Report $Report -Path $repoPath -Rule $config.updatedField -Current $currentSnapshot.Updated -Expected "later than previous updated timestamp because body content changed"
            return
        }
    }

    Add-UnchangedFile -Report $Report -Path $repoPath -Reason "metadata valid"
}

function Complete-Report {
    param(
        [hashtable] $Report,
        [int] $TotalGovernedConsidered,
        [int] $TotalGovernedValidated = 0
    )

    $uniqueFailedFiles = @($Report.failedFiles | ForEach-Object { $_.path } | Sort-Object -Unique)
    $Report.summaryCounts = @{
        totalGovernedFilesConsidered = $TotalGovernedConsidered
        totalGovernedFilesValidated = $TotalGovernedValidated
        filesUpdated = $Report.updatedFiles.Count
        filesUnchanged = $Report.unchangedFiles.Count
        filesSkipped = $Report.skippedFiles.Count
        filesFailed = $uniqueFailedFiles.Count
        staleCheckFilesConsidered = if ($Report.comparison.staleCheckAvailable) { $TotalGovernedValidated - $Report.staleCheckSkippedFiles.Count } else { 0 }
        staleCheckFilesSkipped = $Report.staleCheckSkippedFiles.Count
    }
}

function Write-ReportTable {
    param(
        [string] $Title,
        [object[]] $Rows
    )

    if ($Rows.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host $Title
    Write-Host ("-" * $Title.Length)
    ($Rows | Format-Table -AutoSize | Out-String -Width 240).TrimEnd() | Write-Host
}

function Write-HumanReport {
    param([hashtable] $Report)

    Write-Host ""
    Write-Host "Document metadata report"
    Write-Host "Mode: $($Report.mode)"
    Write-Host "Repository root: $($Report.root)"
    Write-Host "Manifest path: $($Report.manifestPath)"
    if ($Report.mode -eq "Check") {
        Write-Host "Comparison mode: $($Report.comparison.mode)"
        if ($null -ne $Report.comparison.baseSha) {
            Write-Host "Base SHA: $($Report.comparison.baseSha)"
        }
        if ($null -ne $Report.comparison.headSha) {
            Write-Host "Head SHA: $($Report.comparison.headSha)"
        }
        Write-Host "Comparison note: $($Report.comparison.reason)"
    }

    Write-Host "Summary: governed considered=$($Report.summaryCounts.totalGovernedFilesConsidered), validated=$($Report.summaryCounts.totalGovernedFilesValidated), updated=$($Report.summaryCounts.filesUpdated), unchanged=$($Report.summaryCounts.filesUnchanged), skipped=$($Report.summaryCounts.filesSkipped), failed=$($Report.summaryCounts.filesFailed), stale considered=$($Report.summaryCounts.staleCheckFilesConsidered), stale skipped=$($Report.summaryCounts.staleCheckFilesSkipped)"

    $updatedRows = @($Report.updatedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Format = $_.metadataFormat
            Placement = $_.metadataPlacement
            OldVersion = ConvertTo-DisplayValue $_.oldDocVersion
            NewVersion = ConvertTo-DisplayValue $_.newDocVersion
            OldUpdated = ConvertTo-DisplayValue $_.oldUpdated
            NewUpdated = ConvertTo-DisplayValue $_.newUpdated
            Reason = $_.reason
        }
    })
    Write-ReportTable -Title "Updated files" -Rows $updatedRows

    $unchangedRows = @($Report.unchangedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Reason = $_.reason
        }
    })
    Write-ReportTable -Title "Unchanged files" -Rows $unchangedRows

    $skippedRows = @($Report.skippedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Reason = $_.reason
        }
    })
    Write-ReportTable -Title "Skipped files" -Rows $skippedRows

    $failureRows = @($Report.failedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Rule = $_.rule
            Current = ConvertTo-DisplayValue $_.current
            Expected = $_.expected
            Remediation = $_.remediation
        }
    })
    Write-ReportTable -Title "Validation failures" -Rows $failureRows

    $staleSkippedRows = @($Report.staleCheckSkippedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Reason = $_.reason
        }
    })
    Write-ReportTable -Title "Stale-check skipped files" -Rows $staleSkippedRows
}

function ConvertTo-MarkdownTable {
    param(
        [string[]] $Headers,
        [object[]] $Rows,
        [int] $Limit = 100
    )

    if ($Rows.Count -eq 0) {
        return "_None_`n"
    }

    $builder = [System.Text.StringBuilder]::new()
    [void] $builder.AppendLine("| $($Headers -join " | ") |")
    [void] $builder.AppendLine("| $((@($Headers | ForEach-Object { "---" })) -join " | ") |")
    foreach ($row in @($Rows | Select-Object -First $Limit)) {
        $values = foreach ($header in $Headers) {
            $value = Get-PropertyValue -Object $row -Name $header
            ([string] (ConvertTo-DisplayValue $value)).Replace("|", "\|")
        }
        [void] $builder.AppendLine("| $($values -join " | ") |")
    }

    if ($Rows.Count -gt $Limit) {
        [void] $builder.AppendLine()
        [void] $builder.AppendLine("_truncated; see console log or JSON report_")
    }

    $builder.ToString()
}

function Write-GitHubSummary {
    param([hashtable] $Report)

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        return
    }

    $updatedRows = @($Report.updatedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Format = $_.metadataFormat
            Placement = $_.metadataPlacement
            OldVersion = ConvertTo-DisplayValue $_.oldDocVersion
            NewVersion = ConvertTo-DisplayValue $_.newDocVersion
            OldUpdated = ConvertTo-DisplayValue $_.oldUpdated
            NewUpdated = ConvertTo-DisplayValue $_.newUpdated
            Reason = $_.reason
        }
    })
    $skippedRows = @($Report.skippedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Reason = $_.reason
        }
    })
    $failureRows = @($Report.failedFiles | ForEach-Object {
        [pscustomobject]@{
            Path = $_.path
            Rule = $_.rule
            Current = ConvertTo-DisplayValue $_.current
            Expected = $_.expected
            Remediation = $_.remediation
        }
    })

    $summary = [System.Text.StringBuilder]::new()
    [void] $summary.AppendLine("## Document metadata")
    [void] $summary.AppendLine()
    [void] $summary.AppendLine("- Mode: $($Report.mode)")
    [void] $summary.AppendLine("- Governed considered: $($Report.summaryCounts.totalGovernedFilesConsidered)")
    [void] $summary.AppendLine("- Updated: $($Report.summaryCounts.filesUpdated)")
    [void] $summary.AppendLine("- Skipped: $($Report.summaryCounts.filesSkipped)")
    [void] $summary.AppendLine("- Failed: $($Report.summaryCounts.filesFailed)")
    [void] $summary.AppendLine("- Remediation: ``$script:RemediationCommand``")
    [void] $summary.AppendLine()
    [void] $summary.AppendLine("### Updated files")
    [void] $summary.AppendLine((ConvertTo-MarkdownTable -Headers @("Path", "Format", "Placement", "OldVersion", "NewVersion", "OldUpdated", "NewUpdated", "Reason") -Rows $updatedRows))
    [void] $summary.AppendLine("### Skipped files")
    [void] $summary.AppendLine((ConvertTo-MarkdownTable -Headers @("Path", "Reason") -Rows $skippedRows))
    [void] $summary.AppendLine("### Failures")
    [void] $summary.AppendLine((ConvertTo-MarkdownTable -Headers @("Path", "Rule", "Current", "Expected", "Remediation") -Rows $failureRows))

    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $summary.ToString()
}

function Write-MachineReports {
    param([hashtable] $Report)

    if (-not [string]::IsNullOrWhiteSpace($ReportOutputPath)) {
        $reportFullPath = Resolve-InRootPath -RootPath $script:RepositoryRoot -InputPath $ReportOutputPath
        if ($null -eq $reportFullPath) {
            throw "ReportOutputPath must be inside the repository root."
        }
        $Report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $reportFullPath -Encoding utf8NoBOM
    }

    if (-not [string]::IsNullOrWhiteSpace($ChangedFilesOutputPath)) {
        $changedFullPath = Resolve-InRootPath -RootPath $script:RepositoryRoot -InputPath $ChangedFilesOutputPath
        if ($null -eq $changedFullPath) {
            throw "ChangedFilesOutputPath must be inside the repository root."
        }
        [ordered]@{
            changedFiles = @($Report.updatedFiles | ForEach-Object { $_.path })
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $changedFullPath -Encoding utf8NoBOM
    }
}

function Invoke-Main {
    $script:RepositoryRoot = Resolve-RootPath -RequestedRoot $Root
    $script:ManifestFullPath = Resolve-InRootPath -RootPath $script:RepositoryRoot -InputPath $ManifestPath
    if ($null -eq $script:ManifestFullPath) {
        throw "ManifestPath must resolve inside the repository root."
    }

    $manifestReportPath = ConvertTo-RepoRelativePath -RootPath $script:RepositoryRoot -FullPath $script:ManifestFullPath
    $report = New-Report -ModeValue $Mode -RootValue $script:RepositoryRoot -ManifestValue $manifestReportPath
    $manifest = $null

    try {
        $manifest = Read-Manifest -ManifestFile $script:ManifestFullPath
        [object[]] $includeValues = @(Get-NonNullValues -Values $Include)
        $bootstrapPatterns = if ($Mode -eq "Bootstrap" -and $includeValues.Length -gt 0) { $includeValues } else { @() }
        $governedFiles = Resolve-GovernedFiles -Manifest $manifest -BootstrapIncludePatterns $bootstrapPatterns

        if ($Mode -eq "Check") {
            $comparison = Get-ComparisonInfo -RequestedEventName $EventName -RequestedEventPayloadPath $EventPayloadPath -RequestedHeadSha $HeadSha -RequestedBaseSha $BaseSha
            $report.comparison = $comparison
            $selected = @($governedFiles.Values | Sort-Object -Property Path)
            foreach ($record in $selected) {
                Test-GovernedFile -Record $record -Report $report -Comparison $comparison
            }
            Complete-Report -Report $report -TotalGovernedConsidered $selected.Count -TotalGovernedValidated $selected.Count
        }
        else {
            $selected = Get-SelectedGovernedRecords -Manifest $manifest -GovernedFiles $governedFiles -Report $report -ModeValue $Mode
            foreach ($record in $selected) {
                Initialize-OrUpdateFile -Record $record -Report $report -ModeValue $Mode
            }
            Complete-Report -Report $report -TotalGovernedConsidered $selected.Count
        }
    }
    catch {
        if ($null -eq $manifest) {
            Add-FailedFile -Report $report -Path $manifestReportPath -Rule "manifest validation" -Current $_.Exception.Message -Expected "valid document metadata manifest" -Remediation "Fix .github/doc-metadata/doc-metadata-manifest.json and rerun the command."
        }
        else {
            Add-FailedFile -Report $report -Path "." -Rule "execution" -Current $_.Exception.Message -Expected "document metadata command completes successfully" -Remediation "Review the reported error, verify comparison inputs, and rerun the command."
        }
        Complete-Report -Report $report -TotalGovernedConsidered 0
    }
    finally {
        Write-HumanReport -Report $report
        Write-GitHubSummary -Report $report
        Write-MachineReports -Report $report
    }

    if ($report.failedFiles.Count -gt 0) {
        exit 1
    }

    exit 0
}

Invoke-Main
