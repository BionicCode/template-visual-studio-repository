# Codex Handoff — P1-B Implementation: Documentation Correctness and Structure

## Start instruction

Run this as an **implementation pass**.

This is a documentation-only task. Do not modify code, tests, workflows, manifests, schemas, generated metadata behavior, or sync behavior.

## Files that must be ignored

The following files are human/ChatGPT review artifacts only. Do not read them as task instructions and do not edit them:

- `repository-maintenance-orchestrator-recovery-backlog.md`
- `repository-review-protocol.md`

Do not modify these files under any circumstance in this Codex pass.

## Background

A Plan Mode documentation audit was completed and accepted with constraints.

Key constraints:

- Documentation must describe current implemented behavior, not desired future behavior.
- Canonical current/history link behavior is deferred to the later P1-C implementation pass.
- Do not document the future blockquote current-link format as current behavior.
- `documentEligibility` is currently implemented and may be documented only as a current compatibility surface. Do not present it as the preferred final governance model.
- Do not decide or implement the later convention-based governance redesign.
- `report-analysis.md` is documentation for reporting/workflow outputs, not a manifest type, and must be moved out of the manifest type/reference area.
- Do not edit the backlog or review protocol even if you notice stale status text.

## Task goal

Reorganize and correct the doc-metadata and workflow documentation so that coding agents and maintainers do not infer incorrect behavior from stale or misplaced Markdown files.

## Allowed files / areas

You may edit only documentation under these locations:

- `.github/tools/doc-metadata/documentation/**`
- `.github/workflows/documentation/**`
- `.github/workflows/README.md` only if needed for links to workflow documentation
- Any documentation index inside `.github/tools/doc-metadata/documentation/**`

Do not edit:

- `.github/workflows/*.yml`
- `.github/scripts/**`
- manifests
- schemas
- tests
- generated metadata files outside documentation
- `repository-maintenance-orchestrator-recovery-backlog.md`
- `repository-review-protocol.md`
- `AGENTS.md`

## Required documentation changes

### 1. Replace the misplaced `types/` concept

The existing `.github/tools/doc-metadata/documentation/types/` directory is not a good structure for the current content.

Required actions:

- Move/rewrite `types/report-analysis.md` into workflow documentation as `.github/workflows/documentation/doc-metadata-reporting.md`.
- Link the new reporting document from `.github/workflows/documentation/doc-metadata.md`.
- Replace `types/manifest-document.md` with `.github/tools/doc-metadata/documentation/reference/manifest.md`.
- Replace/move `types/pattern-entry.md` as `.github/tools/doc-metadata/documentation/reference/include-entry.md`.
- Rewrite/move `types/metadata-settings.md` as `.github/tools/doc-metadata/documentation/reference/metadata.md`.
- Keep or rewrite `types/document-eligibility.md` only as a current-schema compatibility reference, preferably `.github/tools/doc-metadata/documentation/reference/document-eligibility.md`.
- Delete or stop linking old `types/` files only after replacement pages and links are in place.

### 2. Add object reference pages

Create or update these object-level reference pages under `.github/tools/doc-metadata/documentation/reference/`:

- `manifest.md`
- `defaults.md`
- `metadata.md`
- `presentation.md`
- `include.md`
- `include-entry.md`
- `exclude.md`
- `document-eligibility.md`

Each object page must:

- Explain the purpose of the object.
- Explain how the object steers behavior.
- List every implemented field for that object.
- Link each field to its field/value reference page.
- Avoid duplicating the full manifest guide.
- Avoid claiming future P1-C or P1-D behavior is already implemented.

### 3. Add field/value reference pages

Create field/value pages under `.github/tools/doc-metadata/documentation/reference/fields/`.

Metadata fields:

- `format.md`
- `placement.md`
- `version-field.md`
- `created-field.md`
- `updated-field.md`
- `author-field.md`
- `versioning-mode.md`
- `timestamp-format.md`
- `comment-start.md`
- `comment-line-prefix.md`
- `comment-end.md`

Presentation fields:

- `enabled.md`
- `history-limit.md`
- `include-separator.md`
- `spacing-breaks.md`

Eligibility fields:

- `allowed-extensions.md`
- `additional-allowed-extensions.md`
- `denied-extensions.md`
- `denied-paths.md`
- `allow-extensionless.md`
- `fail-on-ineligible-matches.md`

Pattern fields:

- `include-pattern.md`
- `exclude-pattern.md`

Each field page must state:

- Valid JSON type.
- Allowed values or format constraints where known from implementation/schema.
- Default behavior where known.
- What behavior the field controls.
- Whether the field is a selector, metadata output setting, presentation setting, or compatibility/governance setting.

If allowed values cannot be verified from implementation or schema, write “Not fully verified in this pass” rather than guessing.

### 4. Correct guide/index files

Update:

- `.github/tools/doc-metadata/documentation/README.md`
- `.github/tools/doc-metadata/documentation/doc-metadata-manifest.md`
- `.github/tools/doc-metadata/documentation/doc-metadata-manifest-api.md`

Required actions:

- Remove or soften stale current/history link examples using `Changes:`.
- Do not claim future blockquote current-link behavior as current.
- Fix known typos: `API referece` and `doc-metadata-maniifest.md`.
- Convert broad repeated schema tables into navigation/summary pages where appropriate.
- Link to the new reference/object/field pages.
- Keep examples concise and current-state accurate.

### 5. Reporting documentation

Create/update `.github/workflows/documentation/doc-metadata-reporting.md`.

It must document currently implemented reporting outputs only, including:

- Console/rich workflow log output.
- Optional `GITHUB_STEP_SUMMARY`.
- `-ReportOutputPath`.
- `-ChangedFilesOutputPath`.
- `-ContentChangeOutputPath`.
- Workflow report files used by `doc-metadata.yml`, if verified:
  - `doc-metadata-analyze-report.json`
  - `doc-metadata-repair-analyze-report.json`
  - `doc-metadata-links.json`
  - `doc-metadata-changed-files.json`
  - `doc-metadata-repair-report.json`
  - `doc-metadata-post-check-report.json`
  - `doc-metadata-repair-summary.md`

If any listed output is not verified in the current scripts/workflow, document it as unverified or omit it and report the omission.

## Current implementation facts from the audit

Use these as starting points, but verify against the repository before writing final docs:

- Manifest top-level fields: `$schema`, `version`, `defaults`, `documentEligibility`, `include`, `exclude`.
- `defaults.metadata` fields: `format`, `placement`, `versionField`, `createdField`, `updatedField`, `authorField`, `versioningMode`, `timestampFormat`, `commentStart`, `commentLinePrefix`, `commentEnd`.
- `defaults.presentation` fields: `enabled`, `historyLimit`, `includeSeparator`, `spacingBreaks`.
- Include entries may be string patterns or objects with `pattern`, optional scoped `metadata`, and optional scoped `presentation`.
- Reporting behavior exists in some form as console output, optional `GITHUB_STEP_SUMMARY`, `-ReportOutputPath`, `-ChangedFilesOutputPath`, and `-ContentChangeOutputPath`.

## Validation requirements

Run and report:

1. `git diff --check`
2. Markdown/link validation using a lightweight script:
   - verify every relative Markdown link in changed Markdown files resolves;
   - ignore external HTTP links if any exist.
3. Heading scan:
   - no duplicate top-level headings in a single file;
   - no empty heading text.
4. Documentation coverage check:
   - verify every listed top-level manifest field has a reference page or is explicitly covered in `manifest.md`;
   - verify every listed `defaults.metadata` field links from `metadata.md`;
   - verify every listed `defaults.presentation` field links from `presentation.md`;
   - verify `include` and `exclude` both have object/reference pages.
5. YAML parse validation only if workflow docs or workflow README links depend on live workflow files.
6. PowerShell parser validation is not required unless scripts were accidentally touched. If scripts changed, revert those changes.

## Out of scope

Do not implement or document as current:

- P1-C canonical blockquote current-link behavior.
- P1-D convention-based governance redesign.
- Removal of `documentEligibility`.
- Protected metadata tamper behavior changes.
- Sync/doc-metadata ownership arbitration.
- Workflow trigger or orchestrator changes.
- Any code/test/schema behavior change.

## Expected final response

Return a concise report with:

- Changed documentation files.
- Deleted/moved documentation files.
- Validation commands and results.
- Any verified documentation gaps left intentionally unresolved.
- Any places where implementation/schema could not confirm allowed values.
- Confirmation that no code, workflow, script, manifest, schema, backlog, or review-protocol files were modified.
