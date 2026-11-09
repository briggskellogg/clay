#!/usr/bin/env python3
"""Exercise source privacy boundaries with synthetic files in temporary Git repos."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).with_name("check-source-privacy.py")
SPEC = importlib.util.spec_from_file_location("source_privacy", SCRIPT)
privacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(privacy)


class SourcePrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="clay-privacy-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)

    def stage(self, name: str, contents: bytes):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)
        subprocess.run(["git", "-C", str(self.root), "add", "--", name], check=True)
        return path

    def test_runtime_paths_and_uuid_documents_are_rejected(self):
        for name in ["Library/draft.md", "nested/BACKUPS/x", "Trash/x", "PrivateData/x",
                     "private-data/x", "ClaySync/Records/x", "SyncJournal/x", "writing.claylibrary/draft.md",
                     "00000000-0000-0000-0000-000000000001.md",
                     "00000000-0000-0000-0000-000000000001.json"]:
            with self.subTest(name=name):
                self.assertIsNotNone(privacy.path_reason(name))

    def test_source_and_inline_format_examples_are_allowed(self):
        for name in ["Sources/ClayCore/LibraryRepository.swift", "Tests/ClayCoreTests/LibraryRepositoryTests.swift",
                     "Release/project-destinations.json", "README.md"]:
            self.assertIsNone(privacy.path_reason(name))
        self.assertIsNone(privacy.content_reason(b'let example = "<!-- clay:v1 synthetic -->"'))
        self.assertIsNotNone(privacy.content_reason(b"\xef\xbb\xbf\n <!-- clay:v1 synthetic -->"))

    def test_staged_contents_cannot_be_hidden_by_safe_working_copy(self):
        path = self.stage("innocent-name.md", b"<!-- clay:v1 synthetic -->\n\nSYNTHETIC_PRIVATE_TEXT")
        path.write_text("# Ordinary source documentation\n")
        result = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(self.root), "--staged"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"(index)", result.stderr)
        self.assertNotIn(b"SYNTHETIC_PRIVATE_TEXT", result.stdout + result.stderr)

    def test_working_copy_and_staged_mode_are_distinct(self):
        path = self.stage("README.md", b"# Documentation\n")
        path.write_bytes(b"<!-- clay:v1 synthetic -->\n\nSample")
        self.assertEqual(privacy.inspect(self.root, staged_only=True)[1], [])
        self.assertIn("(working tree)", privacy.inspect(self.root)[1][0])

    def test_untracked_files_are_not_inspected(self):
        self.stage("README.md", b"# Documentation\n")
        (self.root / "untracked.md").write_bytes(b"<!-- clay:v1 synthetic -->\n\nSample")
        count, violations = privacy.inspect(self.root)
        self.assertEqual(count, 1)
        self.assertEqual(violations, [])

    def test_tracked_symlink_is_rejected_without_following_it(self):
        self.stage("README.md", b"# Documentation\n")
        (self.root / "external.md").write_bytes(b"<!-- clay:v1 synthetic -->\n\nSample")
        (self.root / "linked.md").symlink_to(self.root / "external.md")
        subprocess.run(["git", "-C", str(self.root), "add", "--", "linked.md"], check=True)
        violations = privacy.inspect(self.root)[1]
        self.assertEqual(len(violations), 1)
        self.assertIn("links and submodules are rejected", violations[0])
        self.assertNotIn("metadata header", violations[0])

    def test_replaced_parent_directory_link_is_rejected(self):
        self.stage("docs/guide.md", b"# Documentation\n")
        (self.root / "docs").rename(self.root / "untracked-docs")
        (self.root / "docs").symlink_to(self.root / "untracked-docs", target_is_directory=True)
        violations = privacy.inspect(self.root)[1]
        self.assertEqual(len(violations), 1)
        self.assertIn("linked", violations[0])


if __name__ == "__main__":
    unittest.main()
