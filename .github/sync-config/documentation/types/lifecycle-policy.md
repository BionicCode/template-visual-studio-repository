# LifecyclePolicy

Declares how the workflow treats missing, existing, and changed targets.

## Values

| Value | Stage 1 executable | Pull request behavior | Branch maintenance behavior |
|---|---:|---|---|
| `enforce` | Yes | Fail if the target is missing or differs from source. | Create or update the target from source when missing or changed. |
| `seed_once` | Yes | Fail only if the target is missing. Existing target content may differ from source. | Create the target from source only when missing; never overwrite an existing target. |
| `disabled` | Yes | Skip fetch, compare, and verification. | Skip fetch, write, and PR staging. |

## Notes

`disabled` entries remain schema-valid and still participate in whole-manifest validation such as duplicate target detection.
