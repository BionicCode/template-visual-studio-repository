---
doc_version: 1
created: 2026-05-25T14:05:02+02:00
updated: 2026-05-25T14:05:02+02:00
---
# Document Metadata Automation

## Purpose

The document metadata workflow keeps governed repository documentation and text files aligned with repository-owned metadata:

```yaml
---
doc_version: 1
created: 2026-05-25T12:45:00+02:00
updated: 2026-05-25T12:45:00+02:00
---
```

The manifest at `.github/tools/doc-metadata/doc-metadata-manifest.json` is the source of truth. Workflow `paths` filters only decide when GitHub Actions starts; they do not decide which files are governed.

## Metadata Rules

`doc_version` is a positive integer document revision, not SemVer. New or migrated governed files start at `1`. Manual valid version increases are treated as deliberate re-baselines, and the next body-content change increments from the current valid value. Manual decreases are rejected when Git history is available.

`created` is the metadata initialization timestamp and is preserved after initialization. For existing files migrated into this workflow, it means the time metadata was initialized unless a future Git-history inference option is added.

`updated` changes only when governed body content changes. Body content means the file content excluding the managed metadata block.

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

## Modes

Bootstrap mode onboards governed files selected by manifest includes or explicit `-Include` patterns:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Bootstrap -Root .
```

Bootstrap can be used for existing files that predate this workflow. If a governed existing file has no metadata, Bootstrap adds the configured metadata block without changing the body content, sets `doc_version` to `1`, and uses the current metadata initialization timestamp for both `created` and `updated`.

Update mode is for local repair and the optional pre-commit hook:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .
```

Check mode is read-only CI validation:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Check -Root .
```

Check mode validates every governed file for metadata presence and format. Stale `doc_version` and `updated` checks are only applied to governed files whose body changed relative to the selected comparison base.

Each run prints a human-readable task report. Update and Bootstrap can also write machine-readable JSON with `-ReportOutputPath`, while `-ChangedFilesOutputPath` keeps the stable pre-commit hook contract:

```json
{
  "changedFiles": [
    "README.md"
  ]
}
```

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

## Optional Pre-Commit Hook

Install the hook manually:

```bash
cp .github/scripts/doc-metadata/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook runs Update mode and restages only files listed in the stable changed-files JSON output. It does not parse the human-readable task report.

## CI Failures

When CI fails, run:

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .
```

Commit the resulting metadata changes and push again. CI does not auto-commit because it runs with least privilege: `permissions: contents: read`, no write token, no `pull_request_target`, and no pushes.

The workflow currently uses `actions/checkout@v6` with `fetch-depth: 0` and `persist-credentials: false`. If runner compatibility requires a fallback, use `actions/checkout@v4` with the same security settings.
