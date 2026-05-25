---
doc_version: 1
created: 2026-05-26T01:40:37+02:00
updated: 2026-05-26T01:40:37+02:00
---
# Document Metadata Manifest API Reference

This is the public manifest API for repository-owned document metadata automation.

## Feature Support Matrix

| Feature | Schema-valid | Runtime-supported | Notes |
|---|---:|---:|---|
| Manifest-first file governance | Yes | Yes | Manifest include/override patterns define participation. |
| YAML front matter | Yes | Yes | Top placement only. |
| Comment-block metadata | Yes | Yes | Top or bottom placement. Requires comment markers. |
| Body-content-change versioning | Yes | Yes | Only supported versioning mode. |
| Strict UTF-8 text documents | Yes | Yes | Invalid UTF-8 and NUL bytes are reported as binary/non-text. |
| `documentEligibility` extension filters | Yes | Yes | Defaults are applied by script code, not only schema annotations. |
| Automatic same-repository PR repair | N/A | Yes | Workflow writes one repair commit to same-repository PR branches when safe. |
| Fork PR repair | N/A | No | Fork PRs are analyze/report only. |
| SemVer document versions | No | No | `doc_version` is a positive integer. |
| CI direct push to default branch | No | No | Repairs use PR branches or bot repair branches. |

## Type Index

| Type | Placement | Summary |
|---|---|---|
| [`ManifestDocument`](types/manifest-document.md) | Top-level object | Root object containing schema metadata, defaults, eligibility, patterns, and overrides. |
| [`MetadataSettings`](types/metadata-settings.md) | Nested object | Metadata format, placement, field names, and policy. |
| [`DocumentEligibility`](types/document-eligibility.md) | Nested object | Extension, path, and text-safety eligibility policy. |
| [`ManifestOverride`](types/manifest-override.md) | Array item | Pattern-specific metadata settings. |
| [`PatternEntry`](types/pattern-entry.md) | Scalar or object | Repository-relative glob string or future-compatible object entry. |
| [`ReportAnalysis`](types/report-analysis.md) | Report object | Analyze-mode classification output used by the workflow. |

## ManifestDocument Fields

| Field | Required | Type | Description |
|---|---:|---|---|
| `$schema` | Yes | string | Schema reference for editor and tooling validation. |
| `version` | Yes | integer | Must be `1`. |
| `defaults` | Yes | `MetadataSettings` | Default metadata policy for top-level include matches. |
| `documentEligibility` | No | `DocumentEligibility` | Eligibility filter for manifest matches. Defaults are applied by the script when omitted. |
| `include` | Yes | `PatternEntry[]` | Default governed file patterns. |
| `exclude` | Yes | `PatternEntry[]` | Global exclusions. Excludes win over includes. |
| `overrides` | No | `ManifestOverride[]` | Pattern-specific metadata settings. Override includes also add governed files. |

## Validation And Runtime Errors

Manifest validation can reject:

- missing required top-level properties
- unknown top-level properties
- invalid `version`
- missing required default metadata settings
- invalid metadata format, placement, versioning mode, or timestamp format
- YAML front matter with bottom placement, including inherited effective override configuration
- comment-block effective configuration without `commentStart` or `commentEnd`
- invalid extension values in `documentEligibility`
- denied paths that are absolute, drive-qualified, contain backslashes, or traverse with `..`
- unknown `documentEligibility` properties

Runtime validation can report:

- missing metadata
- malformed metadata blocks
- invalid `doc_version`
- version rollback
- stale `doc_version` or `updated` for body changes
- timestamp drift without body changes
- invalid UTF-8 or binary/non-text documents
- ineligible manifest matches

Analyze mode exits `0` after producing outputs when possible, even for repairable or unrecoverable classifications. Check and Update exit non-zero for validation failures.
