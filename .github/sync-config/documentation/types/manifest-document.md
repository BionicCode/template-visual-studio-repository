# ManifestDocument

Top-level JSON object consumed by the reusable sync workflow.

## Shape

```json
{
  "$schema": "./sync-manifest.schema.json",
  "schema_version": 1,
  "entries": [
    {}
  ]
}
```

## Attributes

| Attribute | Required | Type | Description |
|---|---:|---|---|
| `$schema` | No | string | Schema path used by editors and local tooling. It does not decide the authoritative runtime schema. |
| `schema_version` | Yes | number | Manifest schema version. Stage 1 supports only `1`. |
| `entries` | Yes | [`ManifestEntry[]`](manifest-entry.md) | Non-empty list of strict source-to-target mappings. |

## Notes

- The manifest must be an object, not an array.
- Unknown top-level properties are rejected.
- Runtime validation uses the schema bundled with the reusable workflow version being executed.
