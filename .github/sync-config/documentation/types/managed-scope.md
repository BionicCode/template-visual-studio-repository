# ManagedScope

Declares which portion of the target file is managed by the workflow.

## Values

| Value | Stage 1 executable | Markers | Description |
|---|---:|---|---|
| `whole_file` | Yes | Forbidden | The entire target file is managed by the source file content. |
| `outside_markers` | No | Required | Schema-recognized future mode for preserving content inside marker bounds and enforcing content outside them. |
| `inside_markers` | No | Required | Schema-recognized future mode for enforcing content inside marker bounds. |

## Notes

Stage 1 validates marker-scoped entry shape but rejects marker-scoped execution before source fetch or file write.
