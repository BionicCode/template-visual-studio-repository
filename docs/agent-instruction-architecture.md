---
Version: 1
Created: 2026-10-05T14:43:12+00:00
Updated: 2026-10-05T14:43:12+00:00
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

# Agent instruction architecture

## Purpose and ownership

This template distributes a portable repository instruction package. The root
[AGENTS.md](../AGENTS.md) selects shared rules by task and domain before dependent
work. Detailed rules have one authoritative location under `.agent/instructions/`.
The partition preserves the existing rule bodies; the later rule optimization and
Skill audit is deferred.

Personal Codex policy stays in `%USERPROFILE%/.codex/AGENTS.md`. That file and
`config.toml` are outside this repository's distribution contract and were not
changed. Moving the portable engineering, validation, review, and documentation
contract into personal settings would make repositories depend on one machine's
configuration. Other machines, cloud execution, and other agents must receive the
repository package and follow its router. Shared instruction distribution remains
this template's responsibility; the partition reduces duplicated rule bodies.

The template's `.agent/REPOSITORY.md` contains generated-repository defaults and
placeholders. They are not established facts about this template's projects.
Concrete consumer configuration remains consumer-owned. A placeholder never
overrides a populated setting preserved in a legacy repository-specific block.
Conflicting concrete settings require resolution before dependent work.

## File tree and responsibilities

```text
AGENTS.md                               portable contract and deterministic router
AGENT_GUARDRAILS.md                      legacy guardrail bridge
DOCUMENTATION.md                         legacy documentation bridge
CLAUDE.md                               seed-once @AGENTS.md entry point
.agent/
  REPOSITORY.md                         seed-once repository-owned configuration
  REVIEW.md                             seed-once preamble and mutable review Log
  instructions/
    ENGINEERING.md                      always-on engineering baseline
    IMPLEMENTATION.md                    execution, validation, handoff, commit rules
    CODE_REVIEW.md                       independent findings, report, backlog workflow
    DOTNET.md                           .NET / Visual Studio domain rules
    TESTING.md                          test design, execution, and review rules
    GUARDRAILS.md                       contracts, governance, files, security, migration
    DOCUMENTATION.md                    source comments, XML, Markdown, examples
src/AGENTS.md                           .NET bridge and protected local overlays
test/AGENTS.md                          testing bridge and protected local overlays
test/test_instruction_architecture_contract.py
.github/copilot-instructions.md         root bridge and protected local overlays
.github/instructions/dotnet.instructions.md
.github/instructions/test.instructions.md
.github/tools/sync-config/sync-manifest.json
.github/tools/doc-metadata/doc-metadata-manifest.json
docs/agent-instruction-architecture.md   ownership, partition, routing, rollout contract
```

| File or group | Authority and loading | Ownership / excluded content |
| --- | --- | --- |
| Root `AGENTS.md` | Repository-wide precedence, task mode, start sequence, additive triggers | Template-distributed; no detailed workflow body or verified consumer commands |
| `ENGINEERING.md` | Read at the start of every repository task | Shared engineering, scope, planning, layout defaults, analyzer/style rules; no consumer facts |
| `IMPLEMENTATION.md` | Read before implementation or requested commit/PR preparation | Shared validation, self-review, documentation duties, report template, commit guidance; no mutable state |
| `CODE_REVIEW.md` | Read before a code-review request, including exactly `<review>` | Shared review method/report and late backlog reconciliation; never an implementation task list |
| `DOTNET.md` | Read for .NET / Visual Studio code, solutions, projects, SDK, MSBuild, packages, analyzers, validation | Shared domain rules and command examples; no authority to execute commands in review-only mode |
| `TESTING.md` | Read for planning, creating, changing, reviewing, or diagnosing tests, fixtures, assertions, execution | Shared test rules, wherever tests live and for any language |
| `GUARDRAILS.md` | Read before guarded planning/editing; apply relevant criteria in review/analysis | Shared public-contract, instruction, schema/configuration, build, file/security, migration safeguards |
| `DOCUMENTATION.md` | Read for docs/comments/examples/instruction Markdown and changes requiring documentation | Shared documentation rules; no second configuration store |
| `.agent/REPOSITORY.md` | Read at task start if present | Seeded template defaults; thereafter repository-owned facts/commands/overrides |
| `.agent/REVIEW.md` | Read only after independent review findings, or for an explicit backlog request | Seeded preamble/empty Log; thereafter mutable human state; never synchronized over an existing file |
| Root compatibility files, `src/AGENTS.md`, `test/AGENTS.md`, Copilot bridges | Read their canonical destination and apply root routes | Shared outside fences; consumer-owned inside the exact existing fences |
| `CLAUDE.md` | Existing thin `@AGENTS.md` bridge | Seeded only when absent; existing downstream files are not centrally owned |
| Sync / metadata manifests | Explicit distribution and metadata boundaries | Template-owned declarations; no implicit `.agent/` glob distributing state |
| Personal Codex `AGENTS.md` / `config.toml` | Local personal policy/settings | Globally user-owned; no new portable rule dependency |

The canonical files are whole-file shared artifacts. Local facts belong in
`.agent/REPOSITORY.md`, protected legacy blocks, or more specific local instruction
files. Established layouts and concrete local settings take precedence over
template location/name defaults, without weakening validation or correctness.

## Routing and discovery

The root router is authoritative. Read all matching files before dependent work;
ordinary Markdown links are references and do not replace the explicit read.
Routing depends on the requested task and domain, not on an assumed automatic
activation caused by target-file location. Inspect applicable nested instructions
along each selected target path, preferring `AGENTS.override.md` over `AGENTS.md`
at the same directory. Re-evaluate when the scope changes.

| Scenario | Required shared files, in addition to local configuration and overlays |
| --- | --- |
| Production .NET code review | ENGINEERING, CODE_REVIEW, DOTNET; add GUARDRAILS for guarded contracts/configuration and DOCUMENTATION for documentation scope |
| .NET test review | ENGINEERING, CODE_REVIEW, DOTNET, TESTING; add other matching triggers |
| Production .NET implementation with tests and public API changes | ENGINEERING, IMPLEMENTATION, DOTNET, TESTING, GUARDRAILS, DOCUMENTATION |
| .NET build/configuration change | ENGINEERING, IMPLEMENTATION, DOTNET, GUARDRAILS; add TESTING or DOCUMENTATION when their triggers match |
| Ordinary documentation-only change | ENGINEERING, IMPLEMENTATION, DOCUMENTATION |
| Instruction Markdown change | ENGINEERING, IMPLEMENTATION, GUARDRAILS, DOCUMENTATION |
| Review-only architecture analysis | ENGINEERING, GUARDRAILS for instruction architecture, DOCUMENTATION for instruction Markdown; CODE_REVIEW only if a code review is requested |
| Python test implementation | ENGINEERING, IMPLEMENTATION, TESTING; add GUARDRAILS/DOCUMENTATION when triggered; DOTNET is not selected merely because the template serves Visual Studio repositories |
| Explicit commit or PR preparation | ENGINEERING, IMPLEMENTATION, plus files selected by the artifact's scope; existing task-mode boundaries still apply |

The backlog route is deliberately late. Determine findings without consulting
`.agent/REVIEW.md`; then use its allocation/maintenance rules so report and backlog
share identifiers. Matching unchecked findings keep their IDs. For an active Log,
calculate the next ID from all valid IDs, including checked entries, before
removing checked entries. Preserve unchecked notes and user checkbox decisions.
If no unchecked findings remain, the next backlog starts at `R01`. Missing backlog
state does not invalidate the independent report. Implementation self-review does
not invoke this workflow.

Missing mandatory shared files stop dependent work with an explicit boundary.
Missing local configuration allows inspection of concrete preserved local settings
and repository evidence; unresolved material facts still need clarification. The
thin Copilot bridges do not carry stale fallback rule bodies. Their initial YAML
front matter contains `applyTo`; metadata maintenance preserves that field. The
test glob is an entry point, while root task routing covers tests outside `test/`.

## Partition and loss-prevention matrix

| Original instruction group | Canonical destination / disposition |
| --- | --- |
| Root Guardrail Routing | Root guardrail trigger, applied before guarded planning/editing; retained broader guardrail-file triggers |
| Root shared-baseline ownership comment and recommended CI protection | Root ownership contract and GUARDRAILS instruction maintenance; protect shared files and content outside local fences |
| Root Scope and Precedence | Root router; coherent local-file ownership, placeholders, explicit nested discovery, exact `<review>` trigger |
| Root Core Engineering Standards | ENGINEERING, unchanged rule body |
| Root Scope Discovery and Routing | ENGINEERING; root start sequence activates it |
| Root Task Modes | Root authorization boundaries; implementation obligations in IMPLEMENTATION |
| Root Planning and Execution | ENGINEERING, unchanged rule body; approved plans remain authoritative |
| Root File System and Project Structure | ENGINEERING, unchanged defaults subordinate to established layout |
| Root Validation Expectations | IMPLEMENTATION, unchanged rule body |
| Root Completion and Self-Review Requirements | IMPLEMENTATION, including the complete index/offset/UTF-8/newline/path/ownership/write/concurrency/cache/compatibility checklist |
| Root Documentation Is Part of Done | IMPLEMENTATION, all triggers and final checks retained |
| Root Testing Standards | IMPLEMENTATION, unchanged generic duties; TESTING retains the more detailed test workflow |
| Root Analyzer and Style Compliance | ENGINEERING, unchanged rule body |
| Root Documentation and Comments | DOCUMENTATION, with its cross-file layout link corrected |
| Root Code Review Rules | CODE_REVIEW, including priorities, concrete witnesses, category tags, RNN identifiers, required sections, uncertainty boundaries, late backlog reconciliation |
| Root Implementation Completion Report | IMPLEMENTATION, complete report template retained |
| Root Change and Review Style | ENGINEERING, unchanged rule body |
| Root Commit and Pull Request Guidance | IMPLEMENTATION, unchanged rule body |
| Root Keep This File Focused | GUARDRAILS instruction-maintenance rules; root ownership summary |
| Root Repository Specifics | `.agent/REPOSITORY.md`, all four sections and original placeholder/default values retained; protected compatibility block remains |
| `src/AGENTS.md` scope | DOTNET task/domain scope plus nested bridge; no reliance on source-directory discovery |
| `src/AGENTS.md` Repository contract files / Command policy | DOTNET, complete files, sequence, failure and formatting obligations retained; explicit mode boundary added |
| `src/AGENTS.md` analyzer, naming, design rules | DOTNET, unchanged rule bodies |
| `src/AGENTS.md` documentation, test-project, implementation reporting | DOTNET, unchanged rule bodies; local layout/default precedence explicit |
| `test/AGENTS.md` purpose | TESTING task scope plus nested bridge |
| Test Philosophy / Scope and Failure Discipline / Independence and Isolation | TESTING, unchanged rule bodies |
| Naming / Structure / Assertions / Parameterized Tests / Logic and Readability | TESTING, unchanged rule bodies |
| Test Doubles / Async and Time-Sensitive / What Not to Test Directly | TESTING, unchanged rule bodies, including Task-based guidance pending later audit |
| Test Organization / Validation and Reporting / Review Priorities | TESTING, unchanged rule bodies |
| Guardrail purpose, trigger list, non-negotiable safeguards | GUARDRAILS; references updated for routed package ownership |
| Protected surfaces, public contracts, paths/security, schema/config, build/dependencies | GUARDRAILS; all detailed safeguard bodies retained, package/local/state/Claude boundaries added |
| Test/documentation guardrails and completion checklist | GUARDRAILS, unchanged rule bodies |
| Detailed documentation layers, source-comment rules/examples, XML rules/examples/tags | DOCUMENTATION, unchanged bodies except location rule reconciled with established layout and governance locations |
| Markdown triggers/outline, choosing levels, documentation done checks | DOCUMENTATION, unchanged rule bodies |
| Copilot root and .NET copies / test synopsis | Thin bridges to authoritative root/domain rules; duplicate bodies mechanically removed, precedence preserved; stale fallback removed because a missing shared package must be reported |
| Existing repository-specific marker blocks | Exact fences retained in every existing bridge and new test bridge; downstream blocks remain target-owned |
| `.agent/REVIEW.md` | Mutable state artifact; current source bytes/preamble/empty Log retained; seed_once whole_file |
| `CLAUDE.md` | Current source bytes retained; seed_once whole_file bridge |
| Personal Codex evidence/verification baseline | User-global file retained byte-for-byte; no portable rules moved into it |
| Personal Codex settings | User-global `config.toml` retained byte-for-byte |

The engineering, guardrail, implementation, documentation, and domain files still
contain their existing overlapping safeguards. Those are intentionally retained
pending the later audit. The source/documentation examples, command requirements,
test assertion discipline, legacy names, and guardrail `Version: x` label were not
modernized. Only mirrored Copilot bodies were removed mechanically. No Skills were
created, installed, or converted.

## Distribution and migration contract

The [sync manifest](../.github/tools/sync-config/sync-manifest.json) declares each
instruction file explicitly:

| Artifact | Lifecycle | Managed scope |
| --- | --- | --- |
| Seven `.agent/instructions/*.md` files | enforce | whole_file |
| Existing root/nested/Copilot bridges and `test/AGENTS.md` | enforce | outside_markers |
| `.agent/REPOSITORY.md` | seed_once | whole_file |
| `.agent/REVIEW.md` | seed_once | whole_file |
| `CLAUDE.md` | seed_once | whole_file |

The protected fences remain exactly `<!-- BEGIN REPOSITORY SPECIFICS -->` and
`<!-- END REPOSITORY SPECIFICS -->`. Existing shared entries retain their source,
ref, direction, lifecycle, scope, and markers. Unrelated workflow/code-style entries
are unchanged. All instruction sources retain the existing template source at
`main`; no wildcard distributes `.agent/REVIEW.md` or consumer configuration.

Package entries precede seeds and bridges, and root `AGENTS.md` is last among
instruction entry points. The shared engine plans writes before committing them
and writes individual files atomically. This does not establish transaction-wide
rollback for I/O failure across multiple files. During a partial rollout, the
router's missing-file boundary prevents silently proceeding with incomplete rules.

An absent REVIEW.md receives the current preamble and empty Log. An existing file,
including a nonempty human Log, is left byte-identical and is not fetched/replaced
by seed-once synchronization. Existing CLAUDE.md customizations and local repository
configuration receive the same preservation. Seed-once verification checks file
existence; it does not demand equality with the template body.

The [metadata manifest](../.github/tools/doc-metadata/doc-metadata-manifest.json)
governs the seven shared Markdown files. It explicitly excludes local configuration
and review state. Metadata updates must preserve Copilot `applyTo` in the initial
front matter and must not touch the review Log.

This change installs and verifies the package locally. It does not publish source
files, inventory downstream repositories, update consumer manifests, initialize
manifests, dispatch workflows, or claim adoption. Existing consumer manifests do
not gain new declarations automatically. Maintainers must make the complete source
package available at the configured ref, then adopt these exact declarations in a
consumer and inspect the result. Self-source verification before publication can
compare a local router against an older remote `main`; that rollout boundary is
not proof that the local partition failed. The workflow wrapper and sync engine
are not being redesigned.

## Verification and deferred work

Focused contract checks cover local links, router destinations and ownership,
package-before-bridge ordering, exact manifest policies/fences, portable references,
Copilot front matter, and late backlog routing. Fixture checks using the shared
engine cover missing seeds, byte-identical existing files with customized human
state, changed-source replay, protected blocks, and idempotence. Rule preservation
is checked against the pre-partition source sections, alongside a separate diff
self-review. These checks establish file/routing contracts; they do not prove that
every model or agent UI will follow every instruction. Live Claude/Copilot sessions
and downstream deployment remain separate validation boundaries.

| Future Skill candidate | Reason / extraction boundary |
| --- | --- |
| Code review and backlog reconciliation | Coherent multi-step evidence, findings, ID reconciliation, output workflow; preserve independent discovery and human state boundaries |
| Implementation completion and validation | Repeated planning/validation/self-review/handoff workflow; keep universal correctness duties in the portable baseline |
| .NET validation | Repository-configuration discovery and command sequence; preserve task-mode execution boundaries and local command ownership |
| Documentation creation/maintenance | Distinct source/XML/Markdown decisions and examples; preserve public-contract documentation duties |
| Governed instruction/configuration migration | Contract/ownership/source/target checks and rollout validation; preserve non-weakening safeguards |

Skill extraction and individual-rule optimization require a later approved audit.
