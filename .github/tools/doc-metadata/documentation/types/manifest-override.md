---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# ManifestOverride

An override adds or changes metadata behavior for files matched by its `include` patterns.

## Example

```json
{
  "include": [ "specs/**/*.txt" ],
  "metadataFormat": "comment-block",
  "metadataPlacement": "bottom",
  "commentStart": "<!-- doc-metadata",
  "commentEnd": "-->"
}
```

## Fields

| Field | Required | Type | Description |
|---|---:|---|---|
| `include` | No | `PatternEntry[]` | Override include patterns. These also add governed files. |
| `exclude` | No | `PatternEntry[]` | Override-local exclusions. |
| `metadataFormat` | No | enum | Overrides the default metadata format. |
| `metadataPlacement` | No | enum | Overrides the default metadata placement. |
| `versionField` | No | string | Overrides the version field name. |
| `createdField` | No | string | Overrides the created field name. |
| `updatedField` | No | string | Overrides the updated field name. |
| `versioningMode` | No | enum | Must be `body-content-change` when present. |
| `timestampFormat` | No | enum | Must be `iso-8601-offset` when present. |
| `commentStart` | Conditional | string | Required when effective format is `comment-block`. |
| `commentLinePrefix` | No | string | Optional prefix before metadata lines. |
| `commentEnd` | Conditional | string | Required when effective format is `comment-block`. |

## Effective Configuration

The script validates the effective configuration after merging defaults and overrides. An override that only sets `metadataPlacement: "bottom"` while inheriting `yaml-front-matter` is invalid.
