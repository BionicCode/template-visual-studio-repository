# Markers

Marker delimiter object used by marker-scoped managed scopes.

## Shape

```json
{
  "start": "<!-- BEGIN REPOSITORY SPECIFICS -->",
  "end": "<!-- END REPOSITORY SPECIFICS -->"
}
```

## Placement

| Property | Value |
|---|---|
| Placement | Nested object |
| Valid parent | [`ManifestEntry`](manifest-entry.md) |
| Parent property | `markers` |

## Attributes

| Attribute | Required | Type | Description |
|---|---:|---|---|
| `start` | Yes | string | Non-empty start delimiter. |
| `end` | Yes | string | Non-empty end delimiter. |

## Rules

- `start` and `end` must not be identical.
- `markers` is required when `managed_scope` is `outside_markers` or `inside_markers`.
- `markers` is forbidden when `managed_scope` is `whole_file`.
- Marker-scoped entries are accepted by the manifest schema and rejected by current execution rules before source fetch or file write.
