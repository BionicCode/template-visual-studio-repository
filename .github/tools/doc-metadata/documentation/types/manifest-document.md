---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# ManifestDocument

The top-level document metadata manifest object. This type has no parent.

## Shape

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
  "include": [ "README.md" ],
  "exclude": [ "**/build/**" ],
  "overrides": []
}
```

## Fields

| Field | Required | Type | Description |
|---|---:|---|---|
| `$schema` | Yes | string | Relative schema path for editor tooling. |
| `version` | Yes | integer | Must be `1`. |
| `defaults` | Yes | `MetadataSettings` | Default metadata behavior. |
| `documentEligibility` | No | `DocumentEligibility` | Eligibility policy for manifest matches. |
| `include` | Yes | `PatternEntry[]` | Default governed file patterns. |
| `exclude` | Yes | `PatternEntry[]` | Global exclusion patterns. |
| `overrides` | No | `ManifestOverride[]` | Per-pattern metadata settings. |

## Child Values

| Child | Parent property | Type |
|---|---|---|
| Default metadata policy | `defaults` | `MetadataSettings` |
| Eligibility policy | `documentEligibility` | `DocumentEligibility` |
| Default include patterns | `include[]` | `PatternEntry` |
| Default exclude patterns | `exclude[]` | `PatternEntry` |
| Overrides | `overrides[]` | `ManifestOverride` |
