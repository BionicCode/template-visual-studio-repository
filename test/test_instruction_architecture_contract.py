"""Portable instruction contracts and optional offline shared-engine fixtures.

Set INSTRUCTION_SYNC_ENGINE to a checkout of the shared sync script directory
to run the integration fixtures. The engine's jsonschema dependency must be on
PYTHONPATH. No fixture fetches remote sources or edits a consumer repository.
"""

from __future__ import annotations

import contextlib
import importlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path, PurePosixPath
from unittest.mock import patch
from urllib.parse import unquote


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_SOURCE = "BionicCode/template-visual-studio-repository"
PACKAGE_FILES = (
    "ENGINEERING.md",
    "IMPLEMENTATION.md",
    "CODE_REVIEW.md",
    "DOTNET.md",
    "TESTING.md",
    "GUARDRAILS.md",
    "DOCUMENTATION.md",
)
BRIDGE_PATHS = (
    "AGENTS.md",
    "AGENT_GUARDRAILS.md",
    "DOCUMENTATION.md",
    "src/AGENTS.md",
    "test/AGENTS.md",
    ".github/copilot-instructions.md",
    ".github/instructions/dotnet.instructions.md",
    ".github/instructions/test.instructions.md",
)
SEED_PATHS = (".agent/REPOSITORY.md", ".agent/REVIEW.md", "CLAUDE.md")
MARKERS = {
    "start": "<!-- BEGIN REPOSITORY SPECIFICS -->",
    "end": "<!-- END REPOSITORY SPECIFICS -->",
}


def read_text(relative_path: str) -> str:
    return (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")


def manifest_entries() -> list[dict]:
    return json.loads(read_text(".github/tools/sync-config/sync-manifest.json"))["entries"]


def without_code_fences(text: str) -> str:
    return re.sub(r"(?ms)^(`{3,}|~{3,}).*?^\1\s*$", "", text)


class InstructionArchitectureContractTests(unittest.TestCase):
    def test_root_router_remains_below_eight_kibibytes(self) -> None:
        self.assertLess((REPOSITORY_ROOT / "AGENTS.md").stat().st_size, 8192)

    def test_all_canonical_files_are_reachable_from_root(self) -> None:
        destinations = set(re.findall(r"\]\((\.agent/instructions/[^)]+)\)", read_text("AGENTS.md")))
        self.assertEqual({f".agent/instructions/{name}" for name in PACKAGE_FILES}, destinations)

    def test_root_routes_dotnet_and_tests_independently_of_working_directory(self) -> None:
        router = read_text("AGENTS.md")
        dotnet_row = next(line for line in router.splitlines() if line.startswith("| .NET /"))
        testing_row = next(line for line in router.splitlines() if line.startswith("| Planning, creating,"))
        with self.subTest(domain="dotnet"):
            self.assertIn("regardless of working directory", dotnet_row)
        with self.subTest(domain="tests"):
            self.assertIn("wherever tests live and for any language", testing_row)

    def test_root_requires_additive_routes_before_dependent_work(self) -> None:
        self.assertRegex(read_text("AGENTS.md"), r"Load every instruction file.*before the planning, review, editing, or validation.*Routes combine; no row replaces another")

    def test_root_explicitly_inspects_nested_overrides(self) -> None:
        self.assertIn("At each directory prefer `AGENTS.override.md` over `AGENTS.md`", read_text("AGENTS.md"))

    def test_guardrails_route_before_guarded_planning(self) -> None:
        row = next(line for line in read_text("AGENTS.md").splitlines() if line.startswith("| Public APIs/"))
        self.assertIn("Before guarded planning or editing", row)

    def test_review_only_mode_requires_authorization_for_builds_tests_and_formatters(self) -> None:
        self.assertIn("Do not run builds, tests, or formatters unless asked", read_text("AGENTS.md"))

    def test_missing_shared_files_stop_dependent_work(self) -> None:
        self.assertIn("If a mandatory shared file cannot be read, stop the dependent work", read_text("AGENTS.md"))

    def test_local_placeholders_cannot_override_populated_legacy_settings(self) -> None:
        self.assertIn("Template placeholders never override concrete settings in protected legacy blocks", read_text("AGENTS.md"))

    def test_review_backlog_is_loaded_after_independent_findings(self) -> None:
        self.assertIn("After completing a code review and determining all findings, read", read_text(".agent/instructions/CODE_REVIEW.md"))

    def test_implementation_does_not_use_review_backlog_as_task_context(self) -> None:
        self.assertIn("During implementation tasks, do not read, use, or modify `REVIEW.md` unless the user explicitly requests it", read_text(".agent/instructions/CODE_REVIEW.md"))

    def test_review_report_and_backlog_share_stable_identifiers(self) -> None:
        self.assertIn("Use the same `RNN` identifier for a finding in both the review report and `REVIEW.md`", read_text(".agent/instructions/CODE_REVIEW.md"))

    def test_review_allocation_counts_checked_ids_before_removal(self) -> None:
        self.assertIn("For an active backlog, determine the next identifier before removing checked entries. Use one greater than the greatest valid numeric `RNN` identifier currently present anywhere in the `Log`, including checked entries", read_text(".agent/REVIEW.md"))

    def test_review_checkbox_and_unchecked_notes_remain_human_owned(self) -> None:
        with self.subTest(invariant="checkbox"):
            self.assertIn("The user's checkbox state is authoritative. Never infer completion from the current code", read_text(".agent/REVIEW.md"))
        with self.subTest(invariant="notes"):
            self.assertRegex(read_text(".agent/REVIEW.md"), r"Preserve unchecked entries and any user-added notes unchanged")

    def test_review_seed_source_has_empty_log(self) -> None:
        self.assertEqual("", read_text(".agent/REVIEW.md").split("## Log", 1)[1].strip())

    def test_canonical_files_contain_no_repository_specific_marker_blocks(self) -> None:
        for name in PACKAGE_FILES:
            with self.subTest(file=name):
                self.assertNotIn(MARKERS["start"], read_text(f".agent/instructions/{name}"))

    def test_instruction_links_and_heading_fragments_resolve(self) -> None:
        paths = list(BRIDGE_PATHS) + [f".agent/instructions/{name}" for name in PACKAGE_FILES]
        paths += [".agent/REPOSITORY.md", ".agent/REVIEW.md", "README.md", "docs/agent-instruction-architecture.md", ".github/workflows/documentation/sync-managed-files/sync-managed-files.md"]
        for relative_path in paths:
            text = without_code_fences(read_text(relative_path))
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                    continue
                path_part, _, fragment = unquote(target.strip("<>")).partition("#")
                destination = (REPOSITORY_ROOT / relative_path).parent / path_part if path_part else REPOSITORY_ROOT / relative_path
                with self.subTest(source=relative_path, target=target):
                    self.assertTrue(destination.exists(), f"Missing local destination: {destination}")
                    if fragment and destination.is_file():
                        headings = re.findall(r"(?m)^#{1,6}\s+(.+)$", without_code_fences(destination.read_text(encoding="utf-8")))
                        slugs = {re.sub(r"[^\w\s-]", "", heading.lower()).replace(" ", "-") for heading in headings}
                        self.assertIn(fragment, slugs)

    def test_shared_files_do_not_depend_on_absolute_personal_paths(self) -> None:
        for relative_path in ("AGENTS.md",) + tuple(f".agent/instructions/{name}" for name in PACKAGE_FILES):
            with self.subTest(file=relative_path):
                self.assertNotRegex(read_text(relative_path), r"[A-Za-z]:[\\/]|%USERPROFILE%|\$CODEX_HOME")

    def test_each_package_source_is_registered_for_enforced_whole_file_sync(self) -> None:
        entries = manifest_entries()
        for name in PACKAGE_FILES:
            source_path = f".agent/instructions/{name}"
            with self.subTest(file=name):
                entry = next(item for item in entries if item.get("source_path") == source_path)
                self.assertEqual(("enforce", "whole_file", ".agent/instructions/"), (entry["lifecycle_policy"], entry["managed_scope"], entry["target_directory"]))

    def test_local_configuration_review_and_claude_are_seed_once_whole_file(self) -> None:
        for relative_path in SEED_PATHS:
            with self.subTest(file=relative_path):
                entry = next(item for item in manifest_entries() if item.get("source_path") == relative_path)
                self.assertEqual(("seed_once", "whole_file"), (entry["lifecycle_policy"], entry["managed_scope"]))

    def test_all_bridges_retain_the_exact_protected_fences(self) -> None:
        for relative_path in BRIDGE_PATHS:
            with self.subTest(file=relative_path):
                entry = next(item for item in manifest_entries() if item.get("source_path") == relative_path)
                self.assertEqual(("enforce", "outside_markers", MARKERS), (entry["lifecycle_policy"], entry["managed_scope"], entry["markers"]))
                content = read_text(relative_path)
                self.assertEqual((1, 1), (content.count(MARKERS["start"]), content.count(MARKERS["end"])))

    def test_explicit_instruction_sources_exist_and_project_to_the_same_path(self) -> None:
        entries = [entry for entry in manifest_entries() if entry["source_repo"] == TEMPLATE_SOURCE]
        for entry in entries:
            with self.subTest(file=entry.get("source_path")):
                source = entry["source_path"]
                self.assertEqual(source, entry["target_directory"] + PurePosixPath(source).name)
                self.assertTrue((REPOSITORY_ROOT / source).is_file())
                self.assertEqual(("main", "source_to_target", "none"), (entry["source_ref"], entry["direction"], entry["uniqueness_policy"]))

    def test_package_precedes_all_dependent_seeds_and_bridges(self) -> None:
        entries = manifest_entries()
        package_indexes = [index for index, entry in enumerate(entries) if entry.get("source_path", "").startswith(".agent/instructions/")]
        dependent_indexes = [index for index, entry in enumerate(entries) if entry.get("source_path") in SEED_PATHS + BRIDGE_PATHS]
        self.assertLess(max(package_indexes), min(dependent_indexes))

    def test_root_is_the_last_instruction_entry_point(self) -> None:
        entries = [entry for entry in manifest_entries() if entry["source_repo"] == TEMPLATE_SOURCE]
        self.assertEqual("AGENTS.md", entries[-1]["source_path"])

    def test_no_glob_can_distribute_mutable_agent_state(self) -> None:
        self.assertFalse(any(entry["source_repo"] == TEMPLATE_SOURCE and "source_glob" in entry for entry in manifest_entries()))

    def test_metadata_covers_shared_package_and_excludes_local_state(self) -> None:
        manifest = json.loads(read_text(".github/tools/doc-metadata/doc-metadata-manifest.json"))
        with self.subTest(boundary="package"):
            self.assertIn(".agent/instructions/*.md", manifest["include"])
        with self.subTest(boundary="local-state"):
            self.assertTrue({".agent/REPOSITORY.md", ".agent/REVIEW.md"}.issubset(manifest["exclude"]))

    def test_copilot_apply_to_is_in_initial_yaml_front_matter(self) -> None:
        for relative_path in (".github/instructions/dotnet.instructions.md", ".github/instructions/test.instructions.md"):
            with self.subTest(file=relative_path):
                content = read_text(relative_path)
                front_matter = re.match(r"\A---\n(.*?)\n---\n", content, re.DOTALL)
                self.assertIsNotNone(front_matter)
                self.assertEqual(1, len(re.findall(r"(?m)^applyTo:", content)))
                self.assertRegex(front_matter.group(1), r'(?m)^applyTo: ".+"$')


@unittest.skipUnless(os.environ.get("INSTRUCTION_SYNC_ENGINE"), "Set INSTRUCTION_SYNC_ENGINE for offline shared-engine fixtures")
class InstructionSyncEngineFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        engine_directory = Path(os.environ["INSTRUCTION_SYNC_ENGINE"]).resolve()
        if not (engine_directory / "sync_files.py").is_file():
            raise RuntimeError("INSTRUCTION_SYNC_ENGINE must contain the shared sync_files.py")
        sys.path.insert(0, str(engine_directory))
        cls.common = importlib.import_module("common")
        cls.engine = importlib.import_module("sync_files")
        cls.entries = cls.common.build_entries(
            json.loads(read_text(".github/tools/sync-config/sync-manifest.json")),
            cls.common.load_manifest_metadata(cls.common.load_schema(REPOSITORY_ROOT / ".github/tools/sync-config/sync-manifest.schema.json")),
        )

    def entry(self, relative_path: str):
        return next(entry for entry in self.entries if entry.source_path == relative_path and entry.source_repo.casefold() == TEMPLATE_SOURCE.casefold())

    def test_manifest_validates_against_authoritative_schema_and_semantic_rules(self) -> None:
        entries = self.common.validate_and_normalize_manifest(
            read_text(".github/tools/sync-config/sync-manifest.json"),
            REPOSITORY_ROOT,
            REPOSITORY_ROOT / ".github/tools/sync-config/sync-manifest.schema.json",
            self.common.default_rules_path(),
        )
        self.assertEqual(22, len(entries))

    def test_missing_review_is_seeded_with_preamble_and_empty_log(self) -> None:
        self.assert_missing_seed_matches_source(".agent/REVIEW.md")

    def test_missing_claude_is_seeded_with_the_thin_bridge(self) -> None:
        self.assert_missing_seed_matches_source("CLAUDE.md")

    def test_missing_repository_configuration_is_seeded_with_defaults(self) -> None:
        self.assert_missing_seed_matches_source(".agent/REPOSITORY.md")

    def assert_missing_seed_matches_source(self, relative_path: str) -> None:
        source_bytes = (REPOSITORY_ROOT / relative_path).read_bytes()
        with tempfile.TemporaryDirectory(prefix="instruction-seed-") as directory:
            consumer = Path(directory)
            with patch.object(self.engine, "fetch_source_bytes", return_value=source_bytes), contextlib.redirect_stdout(io.StringIO()):
                planned = self.engine.plan_sync_entry(consumer, self.entry(relative_path), None)
                self.engine.commit_planned_writes([planned])
            self.assertEqual(source_bytes, (consumer / relative_path).read_bytes())

    def test_existing_review_remains_byte_identical_during_sync(self) -> None:
        custom_review = "# Human preamble\r\n\r\n## Log\r\n- [ ] R03 [BUG] Café.cs [L2] — keep me\r\n  User note: ä\n- [x] R12 [DOCS] old.md [L1] — checked\r\n".encode("utf-8")
        self.assert_existing_seed_untouched(".agent/REVIEW.md", custom_review)

    def test_existing_claude_customizations_remain_byte_identical(self) -> None:
        self.assert_existing_seed_untouched("CLAUDE.md", b"@AGENTS.md\r\n\r\n# Consumer instructions\r\nKeep our deployment policy.\r\n")

    def test_existing_repository_configuration_remains_byte_identical(self) -> None:
        self.assert_existing_seed_untouched(".agent/REPOSITORY.md", b"# Consumer settings\r\nSolution: ActualProduct.sln\r\nRestore: custom-wrapper.ps1\r\n")

    def assert_existing_seed_untouched(self, relative_path: str, existing_bytes: bytes) -> None:
        with tempfile.TemporaryDirectory(prefix="instruction-existing-") as directory:
            consumer = Path(directory)
            target = consumer / relative_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(existing_bytes)
            normalized = consumer / "normalized-manifest.json"
            self.common.write_normalized_manifest([self.entry(relative_path)], normalized)
            with patch.object(self.engine, "fetch_source_bytes", side_effect=AssertionError("Existing seed must not be fetched")), contextlib.redirect_stdout(io.StringIO()):
                self.engine.sync_entries(consumer, normalized, None)
                self.engine.verify_entries(consumer, normalized, None)
            self.assertEqual(existing_bytes, target.read_bytes())

    def test_changed_review_source_never_updates_an_existing_log(self) -> None:
        existing = b"# Consumer review\n\n## Log\n- [ ] R17 [BUG] keep.cs [L42]\n"
        changed_source = b"# Centrally changed preamble\n\n## Log\n- [ ] R01 [DOCS] must-not-be-installed\n"
        with tempfile.TemporaryDirectory(prefix="instruction-review-replay-") as directory:
            consumer = Path(directory)
            target = consumer / ".agent/REVIEW.md"
            target.parent.mkdir(parents=True)
            target.write_bytes(existing)
            normalized = consumer / "normalized-manifest.json"
            self.common.write_normalized_manifest([self.entry(".agent/REVIEW.md")], normalized)
            with patch.object(self.engine, "fetch_source_bytes", return_value=changed_source), contextlib.redirect_stdout(io.StringIO()):
                self.engine.sync_entries(consumer, normalized, None)
                self.engine.sync_entries(consumer, normalized, None)
            self.assertEqual(existing, target.read_bytes())

    def test_every_legacy_bridge_preserves_customized_protected_bytes(self) -> None:
        protected = "\r\n# Consumer specifics\r\n- Solution: Réel.sln\n- Restore: custom.ps1\r\n".encode("utf-8")
        for relative_path in BRIDGE_PATHS:
            with self.subTest(file=relative_path):
                current = b"Old shared body\r\n" + MARKERS["start"].encode() + protected + MARKERS["end"].encode() + b"\r\nOld footer\r\n"
                expected = self.engine.expected_sync_bytes(self.entry(relative_path), (REPOSITORY_ROOT / relative_path).read_bytes(), current)
                actual = expected.split(MARKERS["start"].encode(), 1)[1].split(MARKERS["end"].encode(), 1)[0]
                self.assertEqual(protected, actual)

    def test_full_instruction_package_sync_preserves_existing_review_log(self) -> None:
        existing_review = b"# Human-owned preamble\r\n\r\n## Log\r\n- [ ] R17 [BUG] keep.cs [L42]\r\n"
        instruction_entries = [entry for entry in self.entries if entry.source_repo.casefold() == TEMPLATE_SOURCE.casefold()]
        with tempfile.TemporaryDirectory(prefix="instruction-full-package-") as directory:
            consumer = Path(directory)
            review_path = consumer / ".agent/REVIEW.md"
            review_path.parent.mkdir(parents=True)
            review_path.write_bytes(existing_review)
            normalized = consumer / "normalized-manifest.json"
            self.common.write_normalized_manifest(instruction_entries, normalized)

            def local_source(entry, source_token):
                return (REPOSITORY_ROOT / entry.source_path).read_bytes()

            with patch.object(self.engine, "fetch_source_bytes", side_effect=local_source), contextlib.redirect_stdout(io.StringIO()):
                self.engine.sync_entries(consumer, normalized, None)
                self.engine.verify_entries(consumer, normalized, None)
            self.assertEqual(existing_review, review_path.read_bytes())

    def test_shared_package_replay_is_idempotent(self) -> None:
        relative_path = ".agent/instructions/ENGINEERING.md"
        source = (REPOSITORY_ROOT / relative_path).read_bytes()
        with tempfile.TemporaryDirectory(prefix="instruction-shared-replay-") as directory:
            consumer = Path(directory)
            with patch.object(self.engine, "fetch_source_bytes", return_value=source), contextlib.redirect_stdout(io.StringIO()):
                first = self.engine.plan_sync_entry(consumer, self.entry(relative_path), None)
                self.engine.commit_planned_writes([first])
                second = self.engine.plan_sync_entry(consumer, self.entry(relative_path), None)
            self.assertIsNone(second)


if __name__ == "__main__":
    unittest.main()
