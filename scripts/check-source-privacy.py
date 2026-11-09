#!/usr/bin/env python3
"""Reject known Clay runtime data in the Git index and tracked working files.

The default checks both snapshots; --staged checks only what Git would commit.
This is a guard for known library formats, not a classifier for arbitrary private
prose. Keep the private library outside the repository and review every commit.
Only Git-listed paths are inspected. Symlinks are rejected, never followed, and
diagnostics contain paths/reasons rather than file contents.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
PRIVATE_DIRECTORIES = {
    "library", "backups", "trash", "privatedata", "private-data",
    "private_data", "claysync", "clay-sync", "syncjournal", "claylibrary",
}
UUID_RUNTIME_FILE = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(md|json)",
    re.IGNORECASE,
)


class PrivacyCheckError(Exception):
    pass


def git(root: Path, *arguments: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], capture_output=True, check=False
    )
    if result.returncode:
        # Git's stderr can include data from a malformed path or configuration.
        raise PrivacyCheckError("Could not inspect the Git index; no privacy check was completed.")
    return result.stdout


def path_reason(name: str) -> str | None:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or str(path) != name:
        return "unsafe repository-relative path"
    # Treat backslashes as separators too, so a path cannot hide runtime data
    # when the repository is subsequently used on Windows.
    parts = name.replace("\\", "/").split("/")
    if any(part.casefold() in PRIVATE_DIRECTORIES
           or part.casefold().endswith(".claylibrary") for part in parts[:-1]):
        return "private library, recovery, or sync directory"
    if UUID_RUNTIME_FILE.fullmatch(parts[-1]):
        return "Clay document or sync-record UUID filename"
    return None


def content_reason(prefix: bytes) -> str | None:
    if prefix.startswith(b"\xef\xbb\xbf"):
        prefix = prefix[3:]
    if prefix.lstrip(b" \t\r\n").lower().startswith(b"<!-- clay:"):
        return "Clay document metadata header"
    return None


def working_prefix(root: Path, name: str) -> bytes | None:
    """Open each path component relative to a descriptor with O_NOFOLLOW."""
    descriptors: list[int] = []
    try:
        directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
        descriptors.append(os.open(root, directory_flags))
        parts = PurePosixPath(name).parts
        for part in parts[:-1]:
            descriptors.append(os.open(part, directory_flags, dir_fd=descriptors[-1]))
        descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=descriptors[-1])
        descriptors.append(descriptor)
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise PrivacyCheckError("tracked path is not a regular file")
        return os.read(descriptor, 4096)
    except FileNotFoundError:
        # A working-tree deletion does not remove the index entry. Its staged
        # contents were checked already and remain part of the next commit.
        return None
    except OSError as error:
        raise PrivacyCheckError("tracked path is unreadable, linked, or not a regular file") from error
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)


def inspect(root: Path, staged_only: bool = False) -> tuple[int, list[str]]:
    top = Path(os.fsdecode(git(root, "rev-parse", "--show-toplevel")).strip()).resolve()
    if top != root.resolve():
        raise PrivacyCheckError("Run this check against the Clay repository itself, not a parent repository.")
    entries = git(root, "ls-files", "--stage", "-z").split(b"\0")
    violations: list[str] = []
    count = 0
    for entry in entries:
        if not entry:
            continue
        metadata, raw_name = entry.split(b"\t", 1)
        mode, object_id, stage = metadata.split()
        name = os.fsdecode(raw_name)
        count += 1
        reason = path_reason(name)
        if stage != b"0":
            reason = "unresolved merge entry"
        elif mode not in {b"100644", b"100755"}:
            reason = "only regular source files are allowed; links and submodules are rejected"
        if reason:
            violations.append(f"{name!r}: {reason}")
            continue
        index_reason = content_reason(git(root, "cat-file", "blob", object_id.decode("ascii"))[:4096])
        if index_reason:
            violations.append(f"{name!r} (index): {index_reason}")
        if not staged_only:
            try:
                prefix = working_prefix(root, name)
                reason = content_reason(prefix) if prefix is not None else None
            except PrivacyCheckError as error:
                reason = str(error)
            if reason:
                violations.append(f"{name!r} (working tree): {reason}")
    return count, violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true", help="check Git index bytes only")
    parser.add_argument("--repo", type=Path, default=ROOT, help="explicit Git repository root")
    arguments = parser.parse_args()
    try:
        count, violations = inspect(arguments.repo, staged_only=arguments.staged)
    except (PrivacyCheckError, OSError, ValueError) as error:
        print(f"Source privacy check failed: {error}", file=sys.stderr)
        return 1
    if violations:
        print("Source privacy check failed. Remove these entries from source control:", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        return 1
    scope = "Git index" if arguments.staged else "Git index and tracked working files"
    print(f"PASS: {count} source entries checked ({scope}); no known Clay private-data formats found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
