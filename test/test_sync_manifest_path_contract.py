from __future__ import annotations

import json
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
CANONICAL_CONFIG_DIRECTORY = ".github/tools/sync-config/"
CANONICAL_MANIFEST_PATH = ".github/tools/sync-config/sync-manifest.json"
LEGACY_CONFIG_DIRECTORY = ".github/sync-config/"
LEGACY_MANIFEST_PATH = ".github/sync-config/sync-manifest.json"


class SyncManifestPathContractTests(unittest.TestCase):
    def read_text(self, relative_path: str) -> str:
        return (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")

    def test_wrapper_reads_only_the_canonical_manifest_path(self) -> None:
        workflow = self.read_text(".github/workflows/sync-managed-files.yml")

        self.assertIn(
            f'manifest_path="{CANONICAL_MANIFEST_PATH}"',
            workflow,
        )
        self.assertNotIn(LEGACY_CONFIG_DIRECTORY, workflow)

    def test_repository_contains_only_the_canonical_manifest(self) -> None:
        self.assertTrue((REPOSITORY_ROOT / CANONICAL_MANIFEST_PATH).is_file())
        self.assertFalse((REPOSITORY_ROOT / LEGACY_MANIFEST_PATH).exists())

    def test_manifest_projects_generic_assets_to_the_canonical_directory(self) -> None:
        manifest = json.loads(self.read_text(CANONICAL_MANIFEST_PATH))
        workflow_entries = [
            entry
            for entry in manifest["entries"]
            if entry["source_repo"] == "BionicCode/workflows"
        ]

        documentation_entry = next(
            entry
            for entry in workflow_entries
            if entry.get("source_glob")
            == ".github/scripts/sync-files-from-manifest/documentation/**/*.*"
        )
        schema_entry = next(
            entry
            for entry in workflow_entries
            if entry.get("source_path")
            == ".github/scripts/sync-files-from-manifest/schema/sync-manifest.schema.json"
        )

        self.assertEqual(
            ".github/tools/sync-config/documentation/",
            documentation_entry["target_directory"],
        )
        self.assertEqual(
            CANONICAL_CONFIG_DIRECTORY,
            schema_entry["target_directory"],
        )

    def test_active_documentation_uses_only_the_canonical_directory(self) -> None:
        for relative_path in (
            ".github/workflows/documentation/sync-managed-files.md",
            ".github/tools/sync-config/documentation/sync-manifest.md",
        ):
            with self.subTest(relative_path=relative_path):
                text = self.read_text(relative_path)
                self.assertIn(CANONICAL_CONFIG_DIRECTORY, text)
                self.assertNotIn(LEGACY_CONFIG_DIRECTORY, text)


if __name__ == "__main__":
    unittest.main()
