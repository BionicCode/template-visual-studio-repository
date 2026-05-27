---
Version: 1
Created: 2026-05-26T19:08:33+00:00
Updated: 2026-05-26T19:08:33+00:00
Author: BionicCode
---
<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>


</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Manifest API Reference

## ManifestDocument

| Property | Type | Required | Description |
| --- | --- | --- | --- |
| `$schema` | string | yes | Schema URI, normally `./doc-metadata-manifest.schema.json`. |
| `version` | integer | yes | Must be `1`. |
| `defaults` | object | yes | Default metadata and presentation settings. |
| `documentEligibility` | object | no | Safety filter for manifest matches. Runtime defaults apply when omitted. |
| `include` | array | yes | Candidate file patterns or scoped include objects. |
| `exclude` | array | yes | Candidate-removal patterns. Default manifest value is `[]`. |

Unknown top-level properties fail validation.

## defaults.metadata

| Property | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `format` | string | yes | `yaml-front-matter` | `yaml-front-matter` or `comment-block`. |
| `placement` | string | yes | `top` | `top` or `bottom`; YAML front matter supports `top` only. |
| `versionField` | string | yes | `Version` | Managed revision field. |
| `createdField` | string | yes | `Created` | Managed initialization timestamp field. |
| `updatedField` | string | yes | `Updated` | Managed body-change timestamp field. |
| `authorField` | string | yes | `Author` | Managed content author field. |
| `versioningMode` | string | no | `body-content-change` | Only supported value. |
| `timestampFormat` | string | no | `rfc3339-utc` | Generated timestamps use UTC `+00:00`. |
| `commentStart` | string | conditional | none | Required when effective format is `comment-block`. |
| `commentLinePrefix` | string | no | none | Optional prefix for comment-block metadata lines. |
| `commentEnd` | string | conditional | none | Required when effective format is `comment-block`. |

## defaults.presentation

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Enables rich presentation for formats that support it. |
| `historyLimit` | integer or null | `20` | Embedded history entry limit; `0` suppresses entries. |
| `includeSeparator` | boolean | `true` | Adds a visual separator before document body. |
| `spacingBreaks` | integer | `2` | Markdown emits `<br>` lines; plain text emits physical blank lines. |

## include

Each entry is either a string pattern or an object:

```json
{
  "pattern": "src/*AGENT*.md",
  "metadata": {
    "versionField": "Version"
  },
  "presentation": {
    "historyLimit": 30
  }
}
```

Object entries inherit defaults and override only specified properties. Use `pattern`, not `fileName`, because entries may be globs.

## documentEligibility

| Property | Type | Runtime Default | Description |
| --- | --- | --- | --- |
| `allowedExtensions` | string[] | `.md`, `.markdown`, `.txt` | Base allowed extensions; if present, replaces defaults. |
| `additionalAllowedExtensions` | string[] | `[]` | Appended allowed extensions. |
| `deniedExtensions` | string[] | `[]` | Always wins over allowed extensions. |
| `deniedPaths` | string[] | `[]` | Repository-relative denied path/glob patterns. |
| `allowExtensionless` | boolean | `false` | Allows files with no extension. |
| `failOnIneligibleMatches` | boolean | `false` | Fails when manifest globs match ineligible files. |

Extensions normalize to leading-dot lowercase values and are compared case-insensitively. Wildcards and path separators are invalid in extension lists.
