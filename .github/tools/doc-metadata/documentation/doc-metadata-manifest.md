---
doc_version: 1
created: 2026-05-26T01:40:37+02:00
updated: 2026-05-26T01:40:37+02:00
---
# Document Metadata Manifest

`doc-metadata-manifest.json` defines the repository-owned document metadata policy. The repository owns this manifest; the script and workflow only execute the policy it describes.

## Complete Shape

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
  ],
  "overrides": [
    {
      "include": [ "specs/**/*.txt" ],
      "metadataFormat": "comment-block",
      "metadataPlacement": "bottom",
      "commentStart": "<!-- doc-metadata",
      "commentEnd": "-->"
    }
  ]
}
```

## Type Placement

| Type | Placement | Valid Parent | Parent Property | Description |
|---|---|---|---|---|
| `ManifestDocument` | Top-level object | None | None | Manifest root containing schema metadata, defaults, eligibility, patterns, and overrides. |
| `MetadataSettings` | Nested object | `ManifestDocument` or `ManifestOverride` | `defaults`, `overrides[]` | Metadata format, field names, placement, and timestamp/version policy. |
| `DocumentEligibility` | Nested object | `ManifestDocument` | `documentEligibility` | Extension, path, and strict-text guard for manifest matches. |
| `ManifestOverride` | Array item | `ManifestDocument` | `overrides[]` | Per-pattern metadata settings and comment-block markers. |
| `PatternEntry` | Scalar or object | `ManifestDocument` or `ManifestOverride` | `include[]`, `exclude[]` | Repository-relative glob or future-compatible pattern object. |

## Glob Semantics

Patterns are matched against repository-root-relative POSIX paths with `/` separators.

`*` matches within one path segment. It does not cross `/`. `*AGENT*.md` matches `AGENTS.md`, `AGENT_GUARDRAILS.md`, and `NET_AGENTS.md`, but not `docs/AGENTS.md`.

`**/` matches zero or more path segments. `**/*AGENT*.md` matches root-level and nested files, including `docs/AGENTS.md`.

Matching is case-sensitive. Add separate patterns for case variants when needed.

## Eligibility Examples

Broad pattern with default eligibility:

```json
{
  "include": [ "AGENTS.*" ]
}
```

`AGENTS.md` is eligible. `AGENTS.cs` is reported as `extension not allowed` and is never mutated.

Allow AsciiDoc as an additional document extension:

```json
{
  "documentEligibility": {
    "additionalAllowedExtensions": [ ".adoc" ]
  },
  "include": [
    "docs/**/*.adoc"
  ]
}
```

Deny generated documentation even when the extension is allowed:

```json
{
  "documentEligibility": {
    "deniedPaths": [
      "docs/generated/**"
    ]
  }
}
```

Fail when broad globs match ineligible files:

```json
{
  "documentEligibility": {
    "failOnIneligibleMatches": true
  }
}
```

## Override Examples

Bottom comment-block metadata for text specifications:

```json
{
  "include": [ "specs/**/*.txt" ],
  "metadataFormat": "comment-block",
  "metadataPlacement": "bottom",
  "commentStart": "<!-- doc-metadata",
  "commentEnd": "-->"
}
```

Markdown front matter must stay at the top. An override that inherits `yaml-front-matter` and sets `metadataPlacement` to `bottom` is invalid.
