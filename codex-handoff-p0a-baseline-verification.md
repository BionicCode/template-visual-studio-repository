# Codex Handoff — P0-A Restored Orchestrator Baseline Verification

## Starting point

Repository snapshot reviewed by ChatGPT on 2026-05-31.

Current inspected HEAD:

```text
2b4e68514b68f3b87b2582a289a70ae32d40123e
chore: update repository maintenance and review protocol documents for clarity and audience specification
```

Restore baseline:

```text
ff13d50ba29de3aab658571ddae2f809570a44f5
```

Current diff from `ff13d50` should be limited to:

```text
D plan-repositoryMaintenanceOrchestrator-refined.prompt.md
D plan-repositoryMaintenanceOrchestrator.prompt.md
A repository-maintenance-orchestrator-recovery-backlog.md
A repository-review-protocol.md
```

The repository may appear dirty after ZIP extraction because of CRLF/LF normalization. Do not treat that as a real implementation diff unless `git diff --ignore-space-at-eol` or an equivalent check shows semantic changes.

## Mission

Perform the first controlled post-restore Codex pass.

Primary goal: verify and, if necessary, minimally clean up the restored orchestrator baseline.

Do not implement the canonical current/history link behavior yet. That is P1-B in the backlog and should be a separate later task.

## Files to inspect first

Read these before changing anything:

```text
AGENTS.md
repository-review-protocol.md
repository-maintenance-orchestrator-recovery-backlog.md
.github/workflows/repository-maintenance.yml
.github/workflows/doc-metadata.yml
.github/workflows/sync-managed-files.yml
.github/scripts/doc-metadata/tests/Invoke-DocMetadataAcceptanceTests.ps1
```

GitHub reusable workflow context: child workflows intended to be called by another workflow must include `on.workflow_call`, and callers invoke reusable workflows at job level via `jobs.<job_id>.uses`, not as step actions.

## Known review observations from ChatGPT

Verified in the uploaded ZIP:

- `repository-maintenance.yml` exists.
- `doc-metadata.yml` exists.
- `sync-managed-files.yml` exists.
- `repository-maintenance.yml` owns normal `pull_request`, `push`, `schedule`, and `workflow_dispatch` triggers.
- `doc-metadata.yml` has only `workflow_call` and `workflow_dispatch` triggers.
- `sync-managed-files.yml` has only `workflow_call` and `workflow_dispatch` triggers.
- `repository-maintenance.yml` calls `doc-metadata.yml` first and `sync-managed-files.yml` last.
- The sync job guard has the intended shape:

```yaml
if: ${{ !cancelled() && needs.normalize.outputs.should_run_sync_managed_files == 'true' && (needs.normalize.outputs.should_run_doc_metadata != 'true' || needs.doc-metadata.result == 'success') }}
```

- `sync-managed-files.yml` still delegates to:

```yaml
BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main
```

- No `diag-p0a.ps1` or `parse-check.ps1` temporary diagnostic scripts were found.
- Root-level planning prompt files are removed in the current HEAD.
- YAML parser validation passed for all workflow files.
- PowerShell parser validation passed for all `.github/**/*.ps1` files.
- In the Linux sandbox, the doc-metadata acceptance suite timed out after the first four PASS lines:

```text
PASS Bootstrap initializes Markdown with human metadata, Author, UTC, and rich presentation
PASS Plain text gets compact metadata, physical blank lines, and no HTML
PASS Body change after dotted version increments first component and refreshes Author
PASS Body change without reliable content context does not create a current link or history
```

Do not assume that timeout is a production bug until it is reproduced locally and isolated. Earlier Windows-local behavior may differ.

## Required first cleanup

`repository-review-protocol.md` still refers to the old backlog filename:

```text
repository-maintenance-fix-backlog.md
```

The active root backlog is now:

```text
repository-maintenance-orchestrator-recovery-backlog.md
```

Fix that filename reference, and only that documentation mismatch, unless additional issues are proven by validation.

## Validation commands

Run these or equivalent commands.

### Workflow YAML parse

```bash
python - <<'PY'
from pathlib import Path
import yaml

for path in sorted(Path(".github/workflows").glob("*.y*ml")):
    with path.open("r", encoding="utf-8") as f:
        yaml.safe_load(f)
    print("YAML OK", path)
PY
```

### PowerShell parser validation

```powershell
$ErrorActionPreference = "Stop"
Get-ChildItem -Path .github -Recurse -Filter *.ps1 | Sort-Object FullName | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $tokens, [ref] $errors) | Out-Null
  if ($errors.Count -gt 0) {
    throw "PowerShell parse failed: $($_.FullName)`n$($errors | Out-String)"
  }
  "PS OK $($_.FullName)"
}
```

### Doc-metadata acceptance tests

```powershell
pwsh -NoLogo -NoProfile -File .github/scripts/doc-metadata/tests/Invoke-DocMetadataAcceptanceTests.ps1
```

If this hangs or fails, do not make broad production changes. Diagnose the exact test and root cause first.

Recommended diagnostic approach for the acceptance test timeout:

1. Identify the first test that does not complete.
2. Add temporary local instrumentation only if needed; remove it before finalizing.
3. Prefer a test-fixture fix if the issue is a weak or invalid fixture.
4. Do not change `update-doc-metadata.ps1` or `resolve-content-change-links.ps1` unless the failing test proves a production bug in the restored baseline.
5. Do not implement P1-B canonical current/history link behavior during this pass.

## Out of scope

Do not implement or modify:

- Canonical current/latest blockquote link behavior.
- `> [<b>View Changes</b>](...)` generation.
- History-link label/URL canonicalization.
- Protected metadata tamper repair behavior.
- Manifest governance or `documentEligibility` removal.
- Sync/doc-metadata ownership arbitration.
- Sync engine behavior.
- `sync-manifest.json` or sync schema semantics.
- Source-side broadcasting.
- `repository_dispatch`.
- Broad documentation rewrites.

## Acceptance criteria

This pass is complete when:

- `repository-review-protocol.md` references the correct active backlog file.
- Workflow YAML validation passes.
- PowerShell parser validation passes.
- The doc-metadata acceptance suite either passes locally or the first blocking hang/failure is documented with a narrow root-cause note.
- No production PowerShell script changed unless a directly reproduced production bug required it.
- No manifest, schema, or sync behavior changed.
- `repository-maintenance-orchestrator-recovery-backlog.md` is updated only for checks proven by the current repository state.
- The final report lists all changed files and validation results.

## Expected changed files

Preferred final diff:

```text
M repository-review-protocol.md
M repository-maintenance-orchestrator-recovery-backlog.md
```

If the acceptance test suite is diagnosed and a minimal test-only fix is required, an additional change to this file may be acceptable:

```text
M .github/scripts/doc-metadata/tests/Invoke-DocMetadataAcceptanceTests.ps1
```

No other changes should be made in this first pass without stopping and explaining why.
