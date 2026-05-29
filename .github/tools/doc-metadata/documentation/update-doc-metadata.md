---
Version: 9
Created: 2026-05-26T19:08:33+00:00
Updated: 2026-05-28T06:35:17+00:00
Author: BionicCode
---
<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>


</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Document Metadata Automation

## What this tool does

The document metadata tool keeps human-readable metadata headers current for governed UTF-8 document files. It writes managed fields such as `Version`, `Created`, `Updated`, and `Author`, adds a generated presentation area for Markdown files, and verifies that document revisions match body-content changes.

The repository manifest is the source of truth. The hosted workflow intentionally does not duplicate manifest include patterns in `paths` filters because GitHub evaluates those filters before the workflow starts. If trigger filters are narrower than the manifest, governed files such as `AGENTS.md`, `DOCUMENTATION.md`, or nested tooling docs can be missed before the tool has a chance to analyze them.

> [!IMPORTANT]
> First-time setup usually requires one Bootstrap or Repair run to initialize existing governed files. For migrated existing files, `Created` means metadata initialization time unless a future Git-history inference feature is added.

## Metadata Header

Markdown files use YAML front matter plus a managed presentation region:

```md
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
---

<!-- doc-metadata-presentation:start -->
[<b>View Commit</b>](https://github.com/owner/repo/commit/0123456789abcdef0123456789abcdef01234567)

<details>
<summary>Change History</summary>

- Updated: <b>2026-05-26T01:40:38+00:00</b> | Author: <b>BionicCode</b> | Changes: [<b>View Commit</b>](https://github.com/owner/repo/commit/0123456789abcdef0123456789abcdef01234567)

</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Document title
```

Plain text files use compact metadata by default:

```text
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
---
--------------------------------------------------------------------------------


Document body starts here.
```

Markdown `spacingBreaks` creates explicit `<br>` lines. Plain text `spacingBreaks` creates physical blank lines using the file newline style. The tool never inserts `<br>` into `.txt` files.

## Reading the Header

`Version` is document revision notation. It may be a positive integer or a dotted numeric value such as `2.1`, but it is not SemVer. Automatic increments update the first component only, so `2.1.2` becomes `3`.

`Created` is the metadata initialization timestamp and is immutable after initialization. Generated timestamps are UTC RFC 3339 values with an explicit `+00:00` offset.

`Updated` changes only when governed document body content changes. Generated values are normalized to UTC `+00:00`.

`Author` is the detected content-change author. Local runs prefer `git config user.name`; GitHub repair prefers the content-changing commit author and avoids `github-actions[bot]` unless the bot authored the content.

Change History is a generated recent-history view. Git remains the canonical full audit log.

The current-version link and the collapsed Change History are generated metadata presentation. They are visually separated from the document body and excluded from body comparison.

## Common Workflows

Same-repository pull request: Analyze runs read-only. If repair is safe, Repair pushes one metadata commit to the PR branch, then runs Check again because `GITHUB_TOKEN` commits may not trigger all follow-up workflows. Runs on `codex/doc-metadata-repair/` branches skip repair publishing so repair PRs do not recursively create more repair PRs.

For pull requests, content history is based on the PR base/head comparison. The repair commit is treated as metadata maintenance unless it also contains the document body change.

Fork pull request: Analyze reports only. The workflow does not run write-capable repair for forks.

Direct push to default branch: Analyze classifies metadata state. Safe repair creates or updates a deterministic bot branch and repair PR instead of pushing to main. The bot branch uses the `codex/doc-metadata-repair/<target>-<hash>` naming convention, and the workflow uses concurrency plus conservative `--force-with-lease` publishing so older runs do not race newer repair updates.

For push events, content history is based on the pushed `before..after` range. A later metadata repair commit is not used as the content-change reference.

`workflow_dispatch`: Runs the same Analyze/Repair/Final Status flow for the selected branch. If no explicit or safely derived comparison context exists, the tool can repair metadata but does not create a new content Change History entry.

Local Bootstrap/Update: Developers can still run the script manually, but normal maintenance should be handled by hosted repair automation.

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Bootstrap -Root .
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Check -Root .
```

## Repair Safety

The tool compares body content after removing the metadata block and the entire generated presentation/separator region. Generated history, current-version links, separators, and spacing updates cannot trigger a self-perpetuating version bump.

All governed eligible files must keep metadata. Repair may update files beyond the one that triggered a workflow if other governed files have repairable metadata defects, such as missing headers or malformed presentation boundaries. The tool does not intentionally remove generated metadata from governed eligible files.

Document history tracks document content versions, not metadata maintenance. Tool-only metadata initialization, formatting repair, timestamp repair, URL repair, and safe tamper restoration are reported in console output, JSON reports, GitHub summaries, and repair PR bodies. They are not embedded as Change History entries.

Metadata-only repair preserves the previous proven current-version link. It does not re-fetch, replace, remove, or rewrite that link unless the managed presentation must be restored from trusted previous generated content. A body change with a proven replacement link updates the current-version link; a body change without reliable content-change context clears that top link rather than preserving an older version's link. Unproven links are not adopted as trusted generated history.

Manual `Version` increases are allowed as a rebaseline when the body is unchanged and the rest of the managed metadata is valid. Version decreases are rejected by default.

Custom front matter fields are preserved and ignored:

```yaml
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
Tool: Visual Studio Code
ReviewState: Draft
---
```

Generated history entries are tamper-safe. If a generated history entry changes, the tool restores it from trusted previous generated history when safe. If restoration is not safe, the file is reported as unrecoverable.

> [!WARNING]
> Unsafe repair cases include version rollback, invalid version values, ambiguous malformed metadata, malformed presentation without trusted previous state, and fork PRs where write access is unavailable.

## URLs in Change History

New history entries use the most precise stable link available:

1. Verified file-specific changes URL for the document path and content-change context. This is future support and is not emitted in v1.
2. Stable, proven content-change commit URL with link text `View Commit`.

If no reliable content-change context exists, the tool does not add a current-version link and does not add a new Change History entry.

The workflow distinguishes the content-change commit from a later bot repair commit. For each repaired file, the trusted resolver script asks `update-doc-metadata.ps1 -Mode ContentChanges` to compare the managed body at each candidate commit. The newest commit that actually changed that file's body becomes the history context. The workflow does not assign `github.sha` or the PR head commit to every file.

Merge commits with multiple parents are ambiguous for this purpose and are skipped rather than guessed. Root commits are treated as newly introduced content only when the governed file exists in the commit and was absent before.

The script performs lexical URL validation before emitting or preserving managed history links. It rejects unsafe schemes such as `javascript:`, `data:`, and `file:`, relative or malformed URLs, unrelated repositories or hosts, `github.io`, generic repository home URLs, normal `/blob/<ref>/<path>` file-at-version URLs, `/tree/` URLs, `/compare/` URLs, and link-map entries whose declared path does not match the governed file. If repository identity cannot be resolved, managed history URLs are rejected instead of accepted generically. The script remains network-free; workflow steps are responsible for any live URL resolution before passing links to the script.

History entries and the current-version link must reference the document content change, not the metadata repair commit unless that same commit also changed document body content. `View Changes` is reserved for future verified file-specific changes support and is rejected in managed presentation for this v1 pass. Proven commit URL fallbacks are labeled `View Commit`; a commit URL labeled `View Changes` fails validation. If no reliable content-change context exists, the tool repairs metadata without adding a new Change History entry. Metadata-only repair preserves the existing proven current-version link, while body-changing repair clears that link so it cannot point at an older document version.

The repair link map is proof-bearing data. A commit fallback entry must include the governed `path`, `url`, matching `commitSha`, and `bodyChanged: true`; the metadata script independently verifies that the commit changed the file's managed body before emitting the link.

Existing committed history URLs are not re-fetched every run. Integrity is checked by comparing the current generated history with the previous trusted generated history.

## Final Status

The workflow has Analyze, Repair, post-repair Check, and Final Status stages. A successful repair followed by a passing post-repair Check should produce a passing final status. The repair job generates one Markdown report source that is appended to the GitHub step summary and reused as the repair PR body.

Repair PR bodies include the workflow run URL, run ID, run number, event, actor, target branch, source SHA, repair branch, repair commit SHA, repaired files, initialized files, skipped files, remaining failed files, remaining unrecoverable files, and the post-repair Check result. This makes each repair PR traceable to the exact workflow run that produced it.

If final status fails after a repair, it lists the repaired files, remaining invalid files, and remaining unrecoverable files from the post-repair Check report. The repair may have succeeded for one file while other governed files still have unrepaired or unrecoverable metadata failures.

## Troubleshooting

`repairableFiles`: hosted repair can safely update these files.

`unrecoverableFiles`: manual intervention is required before repair.

`ineligibleFiles`: the manifest matched files that are not eligible document text files.

`ignoredBinaryOrNonText`: the file is not strict UTF-8 or contains binary data. Convert it to UTF-8 if it should be managed.

`historyTamperDetected`: generated history was edited.

`historyRestoredFromTrustedPrevious`: generated history was restored safely.

> [!TIP]
> Use `documentEligibility` to allow additional document extensions, deny generated paths, or fail when broad globs match ineligible files.
