# Direction

Declares the synchronization direction for a manifest entry.

## Values

| Value | Stage 1 executable | Description |
|---|---:|---|
| `source_to_target` | Yes | Fetch source content and verify or write the caller repository target. |
| `target_to_source` | No | Schema-recognized for future design, but rejected before execution in Stage 1. |
| `two_way` | No | Schema-recognized for future design, but rejected before execution in Stage 1. |

## Notes

Stage 1 never writes back to source repositories.
