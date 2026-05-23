# UniquenessPolicy

Declares whether repository-wide basename uniqueness is enforced for an entry.

## Values

| Value | Stage 1 executable | Description |
|---|---:|---|
| `basename_unique` | Yes | Fail validation when any tracked repository file outside the declared target path shares the target basename. |
| `none` | Yes | Do not scan the repository for same-basename files. |

## Notes

- `basename_unique` does not delete extra files.
- `basename_unique` is opt-in per entry.
- Same-basename files are allowed when entries use `uniqueness_policy: none`, provided target paths and source identities remain unique.
