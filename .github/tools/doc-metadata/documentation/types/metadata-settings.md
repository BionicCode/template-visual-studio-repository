---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# MetadataSettings

Metadata behavior for files matched by a manifest include pattern. `defaults` requires all fields. Overrides may specify only fields they change, but the merged effective configuration must still be valid.

## Fields

| Field | Required in defaults | Type | Description |
|---|---:|---|---|
| `metadataFormat` | Yes | enum | `yaml-front-matter` or `comment-block`. |
| `metadataPlacement` | Yes | enum | `top` or `bottom`. YAML front matter supports only `top`. |
| `versionField` | Yes | string | Managed positive-integer document revision field. |
| `createdField` | Yes | string | Managed immutable metadata initialization timestamp field. |
| `updatedField` | Yes | string | Managed body-content-change timestamp field. |
| `versioningMode` | Yes | enum | Must be `body-content-change`. |
| `timestampFormat` | Yes | enum | Must be `iso-8601-offset`. |
| `commentStart` | Conditional | string | Required for effective `comment-block` metadata. |
| `commentLinePrefix` | No | string | Optional prefix before each metadata line in a comment block. |
| `commentEnd` | Conditional | string | Required for effective `comment-block` metadata. |

## Placement Rules

`yaml-front-matter` must use `metadataPlacement: "top"`.

`comment-block` may use `top` or `bottom`. Bottom placement is useful for text specifications where metadata should not interrupt the opening content.
