# ManagedScope

Declares which portion of the target file is managed by the workflow.

## Placement

| Property | Value |
|---|---|
| Placement | Enum string |
| Valid parent | [`ManifestEntry`](manifest-entry.md) |
| Parent property | `managed_scope` |

## Values

| Value | Supported | Markers | Description |
|---|---:|---|---|
| `whole_file` | Yes | Forbidden | The entire target file is managed by the source file content. |
| `outside_markers` | No | Required | Accepted by the manifest schema and rejected by current execution rules before source fetch or write. |
| `inside_markers` | No | Required | Accepted by the manifest schema and rejected by current execution rules before source fetch or write. |

## Notes

Current marker validation criteria:

- `markers` is required for `outside_markers` and `inside_markers`.
- `markers` is forbidden for `whole_file`.
- `markers.start` and `markers.end` are required non-empty strings.
- `markers.start` and `markers.end` must not be identical.
