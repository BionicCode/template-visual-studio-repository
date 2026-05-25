---
doc_version: 2
created: 2026-05-25T14:05:02+02:00
updated: 2026-05-26T01:40:38+02:00
---
# Document Metadata Automation

## Purpose

The document metadata tool keeps repository-owned document metadata current for governed Markdown and document-like text files. It manages three fields:

```yaml
---
doc_version: 1
created: 2026-05-25T12:45:00+02:00
updated: 2026-05-25T12:45:00+02:00
---
```

The manifest at `.github/tools/doc-metadata/doc-metadata-manifest.json` is the source of truth. Workflow `paths` filters only decide when GitHub Actions starts; they do not decide which files are governed.

## Lifecycle

`Analyze` is read-only. It validates governed files, classifies repairable and unrecoverable problems, reports ineligible manifest matches, and emits machine-readable output for the workflow.

`Repair` is hosted automation. The workflow uses trusted script code, treats branch files as data, repairs only safe cases, commits to a same-repository pull request branch or a deterministic bot repair branch, and runs a mandatory post-repair Check.

`Check` is read-only validation. It validates every eligible governed file for metadata presence and format, then performs stale `doc_version` and `updated` checks only for files whose body changed relative to the selected comparison base.

`Update` is local or workflow repair mode. It initializes missing metadata, repairs stale metadata for body-content changes, restores safe timestamp drift from previous metadata, and writes only actual repairs.

`Bootstrap` is explicit onboarding mode for existing governed files. It can initialize metadata for files that predate this tool without changing body content.

## Metadata Rules

`doc_version` is a positive integer document revision, not SemVer. New or migrated governed files start at `1`. Manual valid version increases are treated as deliberate re-baselines, and the next body-content change increments from the current valid value. Manual decreases are rejected when Git history is available.

`created` is the metadata initialization timestamp and is preserved after initialization. For existing files migrated into this workflow, it means the time metadata was initialized unless a future Git-history inference option is added.

`updated` changes only when governed body content changes. Body content means the file content excluding the managed metadata block.

## Document Eligibility

Manifest patterns may be broad, but only eligible document-like text files may be analyzed for repair or mutated.

Default eligible extensions are `.md`, `.markdown`, and `.txt`. Source, build, config, and syntax-bound formats such as `.cs`, `.json`, `.yml`, `.ps1`, `.sh`, `.js`, `.ts`, `.csproj`, `.sln`, and `.slnx` are not eligible by default even if a manifest glob matches them.

Example:

```json
"include": [
  "AGENTS.*"
]
```

`AGENTS.md` is eligible by default. `AGENTS.cs` is ignored and reported as `extension not allowed`. The workflow must not modify `AGENTS.cs`.

The tool uses strict UTF-8 with optional BOM preservation. If an otherwise eligible document has invalid UTF-8 or NUL bytes, it is classified as `ignoredBinaryOrNonText` and is never rewritten. Convert the document to UTF-8 if it should be managed by doc-metadata.

## Metadata Placement

Markdown and Markdown-like files use YAML front matter at the top of the file. Front matter is intentionally top-only because Markdown tools expect YAML front matter before document content.

Non-Markdown text files can use manifest-configured comment-block metadata. Comment blocks default to top placement but may be placed at the bottom for selected patterns:

```json
{
  "include": [ "specs/**/*.txt" ],
  "metadataFormat": "comment-block",
  "metadataPlacement": "bottom",
  "commentStart": "<!-- doc-metadata",
  "commentEnd": "-->"
}
```

Example bottom comment block:

```text
Specification body.

<!-- doc-metadata
doc_version: 1
created: 2026-05-25T12:45:00+02:00
updated: 2026-05-25T12:45:00+02:00
-->
```

## First-Time Setup

Start with the repository-owned manifest:

```json
{
  "$schema": "./doc-metadata-manifest.schema.json",
  "version": 1,
  "defaults": {
    "metadataFormat": "yaml-front-matter",
    "metadataPlacement": "top",
    "versionField": "doc_version",
    "createdField": "created",
    "updatedField": "updated",
    "versioningMode": "body-content-change",
    "timestampFormat": "iso-8601-offset"
  },
  "documentEligibility": {
    "allowedExtensions": [ ".md", ".markdown", ".txt" ],
    "additionalAllowedExtensions": [],
    "deniedExtensions": [],
    "deniedPaths": [],
    "allowExtensionless": false,
    "failOnIneligibleMatches": false
  },
  "include": [
    "README.md",
    "docs/**/*.md",
    "docs/**/*.markdown"
  ],
  "exclude": [
    "**/.git/**",
    "**/node_modules/**",
    "**/build/**",
    "**/dist/**"
  ]
}
```

Initialize existing governed files:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Bootstrap -Root .
```

Run read-only validation:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Check -Root .
```

## Local Commands

Analyze without mutating files:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Analyze -Root . -ReportOutputPath doc-metadata-report.json
```

Repair locally:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .
```

Onboard selected files:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Bootstrap -Root . -Include "docs/**/*.md"
```

`-ChangedFilesOutputPath` writes the stable hook contract:

```json
{
  "changedFiles": [
    "README.md"
  ]
}
```

## GitHub Automation

The workflow has three concepts:

- Analyze job: read-only `contents: read`, trusted script checkout, working files as data, always produces report outputs when possible.
- Repair job: write-capable only when repair is required and safe. Same-repository pull requests get one repair commit pushed to the PR branch. Fork pull requests are analyze-only.
- Final status job: fails for unrecoverable analysis results, unsafe repair needs, repair job failures, fork PRs that need repair, or post-repair Check failures.

For push and `workflow_dispatch`, repairs go to a deterministic bot branch and the workflow creates or updates a repair PR. Repairs do not push directly to `main` or `master`.

The workflow uses `GITHUB_TOKEN` in v1. GitHub may not trigger every follow-up workflow from commits created with `GITHUB_TOKEN`, so the repair job runs its own post-repair Check. Branch protection that requires checks on the latest commit may need a manual rerun, a future GitHub App token design, or bot-repair-PR mode. No PAT or GitHub App token is configured by this tool.

Repository settings must allow GitHub Actions to create pull requests for bot repair PRs.

## Adding Or Excluding Files

Add governed Markdown files by extending the manifest include list:

```json
"include": [
  "README.md",
  "docs/**/*.md",
  ".github/tools/doc-metadata/documentation/**/*.md"
]
```

Generated, vendored, dependency, build, and artifact directories should remain excluded through the manifest `exclude` list. Excludes win over includes, and explicit `-Path` restrictions cannot bypass manifest exclusions.

Use `documentEligibility.deniedPaths` for additional safety filters over otherwise eligible document files:

```json
"documentEligibility": {
  "deniedPaths": [
    "docs/generated/**"
  ]
}
```

## Governing Non-Markdown Text

Use an override for `.txt` or another explicitly allowed document extension:

```json
{
  "include": [ "specs/**/*.txt" ],
  "metadataFormat": "comment-block",
  "metadataPlacement": "bottom",
  "commentStart": "<!-- doc-metadata",
  "commentEnd": "-->"
}
```

To allow a non-default document extension such as `.adoc`, append it with `additionalAllowedExtensions`:

```json
"documentEligibility": {
  "additionalAllowedExtensions": [ ".adoc" ]
}
```

## Glob Semantics

Manifest patterns are matched against repository-root-relative paths using `/` separators.

`*` matches characters within a single path segment and does not cross directory separators. For example, `*AGENT*.md` matches root-level files such as `AGENTS.md`, `AGENT_GUARDRAILS.md`, and `NET_AGENTS.md`, but it does not match `docs/AGENTS.md`.

Use `**/` for recursive matching. For example, `**/*AGENT*.md` matches both root-level files and nested files such as `docs/AGENTS.md`.

Matching is case-sensitive. If a repository needs to govern case variants such as `agents.md`, add explicit patterns for those variants.

## Reports

Every run prints a console report. When `GITHUB_STEP_SUMMARY` is available, the script appends a bounded Markdown summary. Use `-ReportOutputPath` to write the structured JSON report.

Report categories include:

- `updatedFiles`: files actually rewritten by Bootstrap or Update.
- `unchangedFiles`: files with valid metadata or metadata-only no-op changes.
- `skippedFiles`: deleted files, non-governed explicit paths, excluded files, and blocked symlinks.
- `failedFiles`: validation or execution failures.
- `ineligibleFiles`: manifest matches rejected by documentEligibility.
- `ignoredByEligibility`: extensionless or extension-not-allowed matches.
- `ignoredByDeniedPath`: matches rejected by `documentEligibility.deniedPaths`.
- `ignoredByDeniedExtension`: matches rejected by `documentEligibility.deniedExtensions`.
- `ignoredBinaryOrNonText`: matches that are not strict UTF-8 text.
- `analysis.repairableFiles`: files the workflow may repair safely.
- `analysis.unrecoverableFiles`: files requiring human attention.

## What Happened In CI?

If the final status passed and no repair PR was opened, metadata was already valid or only ineligible manifest matches were reported with `failOnIneligibleMatches=false`.

If the workflow pushed a commit to your same-repository PR branch, it found repairable metadata drift and ran post-repair Check. Review the commit before merging.

If the workflow opened or updated a bot repair PR, the triggering push or manual run needed metadata repair. Merge the bot PR after review.

If the final status failed on a fork PR, the workflow could not push repair commits to the fork. Run Update locally or ask a maintainer to apply a repair branch.

If CI reports `extension not allowed`, narrow the manifest pattern, add a document extension through `additionalAllowedExtensions`, or leave the file ignored if it is not documentation.

If CI reports `ignoredBinaryOrNonText`, convert the document to UTF-8 if it should be managed by doc-metadata.

If CI reports an unrecoverable metadata edit, restore managed timestamps or doc_version from history, or run Update when the report says repair is safe.

## Optional Pre-Commit Hook

Install the hook manually:

```bash
cp .github/scripts/doc-metadata/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook runs Update mode and restages only files listed in the stable changed-files JSON output. It does not parse the human-readable task report.

## Checkout Version

The workflow uses `actions/checkout@v6` with `fetch-depth: 0`. If runner compatibility requires a fallback, use `actions/checkout@v4` with the same security settings.
