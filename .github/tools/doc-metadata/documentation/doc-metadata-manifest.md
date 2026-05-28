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

# Document Metadata Manifest

> [!INFO]
> See [API referece](../documentation/doc-metadata-manifest-api.md) for manifest types  documentation.

## Purpose

`.github/tools/doc-metadata/doc-metadata-manifest.json` defines candidate files, metadata defaults, presentation defaults, and eligibility rules. It is the only governance policy source for document metadata.

## Defaults First

Defaults apply to every string include entry and to object include entries unless they override specific settings.

```json
{
  "defaults": {
    "metadata": {
      "format": "yaml-front-matter",
      "placement": "top",
      "versionField": "Version",
      "createdField": "Created",
      "updatedField": "Updated",
      "authorField": "Author",
      "versioningMode": "body-content-change",
      "timestampFormat": "rfc3339-utc"
    },
    "presentation": {
      "enabled": true,
      "historyLimit": 20,
      "includeSeparator": true,
      "spacingBreaks": 2
    }
  }
}
```

File-format conventions are applied after manifest defaults. Markdown files get rich presentation by default. Plain text files get compact metadata by default.

## Participation Flow

`include` selects candidate files.

`exclude` removes candidates from broad include patterns. The default is `[]`.

`documentEligibility` filters candidates by extension, denied path, strict UTF-8 text decoding, and binary detection.

Only eligible governed files can be analyzed, updated, bootstrapped, or repaired.

## Include Entries

String include entries use defaults:

```json
{
  "include": [
    "README.md",
    "*AGENT*.md",
    "docs/**/*.markdown"
  ]
}
```

Object include entries use `pattern` plus scoped settings:

```json
{
  "include": [
    {
      "pattern": "src/*AGENT*.md",
      "presentation": {
        "historyLimit": 30,
        "includeSeparator": false,
        "spacingBreaks": 1
      }
    }
  ]
}
```

If multiple include entries match the same file, their effective configuration must be identical. Conflicting matches fail validation instead of being silently merged.

## Eligibility Example

The pattern `AGENTS.*` may match `AGENTS.md` and `AGENTS.cs`. With default eligibility, only `AGENTS.md` is managed because `.cs` is not a default document extension.

```json
{
  "include": [
    "AGENTS.*"
  ],
  "documentEligibility": {
    "allowedExtensions": [".md", ".markdown", ".txt"],
    "additionalAllowedExtensions": [],
    "deniedExtensions": [],
    "deniedPaths": [],
    "allowExtensionless": false,
    "failOnIneligibleMatches": false
  }
}
```

> [!TIP]
> Add `additionalAllowedExtensions` for document-like formats such as `.adoc`. Do not broadly allow source or config extensions unless the files are truly human-facing documents.

## Broad Include with Exclude

```json
{
  "include": [
    "docs/**/*"
  ],
  "exclude": [
    "docs/generated/**"
  ]
}
```

Use `exclude` for intentionally broad globs. Do not rely on workflow `paths` filters to define governed files.

## Plain Text Defaults

`.txt` files are eligible by default, but rich Markdown presentation is disabled by convention. They receive compact metadata and a plain separator with physical blank lines.

```json
{
  "include": [
    {
      "pattern": "**/*.txt",
      "presentation": {
        "enabled": false,
        "historyLimit": 0,
        "includeSeparator": true,
        "spacingBreaks": 2
      }
    }
  ]
}
```

## Scoped Settings

Scoped configuration belongs directly on include object entries so file selection and behavior stay together.
