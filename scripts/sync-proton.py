#!/usr/bin/env python3
"""Conservatively mirror committed Clay source into a Proton Drive folder."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile


MANIFEST = ".clay-sync-manifest.json"
EXCLUDED_PARTS = {".git", ".build", "build", "deriveddata", "xcuserdata", "__pycache__", "library", "backups", "trash", "privatedata", "claysync", "syncjournal"}


class SyncError(Exception):
    pass


def discover_destination():
    cloud_storage = Path.home() / "Library/CloudStorage"
    candidates = []
    if cloud_storage.is_dir():
        for account in cloud_storage.iterdir():
            projects = account / "[projects]"
            if account.name.startswith("ProtonDrive-") and account.is_dir() and projects.is_dir():
                candidates.append(projects / "clay")
    if len(candidates) != 1:
        raise SyncError(
            f"Found {len(candidates)} Proton Drive [projects] folders; "
            "pass --destination with the intended absolute Clay folder."
        )
    return candidates[0]


def git(root, *arguments, check=True):
    result = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True)
    if check and result.returncode:
        raise SyncError(result.stderr.decode(errors="replace").strip())
    return result


def relative_name(value):
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or str(path) != value or value == ".":
        raise SyncError(f"Unsafe relative path: {value!r}")
    return value


def excluded(name):
    path = PurePosixPath(name)
    lower = path.name.lower()
    return (
        any(part.lower() in EXCLUDED_PARTS for part in path.parts)
        or lower in {".ds_store", "signing.local.xcconfig", "id_rsa", "id_ed25519"}
        or lower.startswith(".env")
        or lower.endswith((".p12", ".p8", ".pem", ".key", ".mobileprovision", ".provisionprofile", ".xcuserstate"))
    )


def check_ancestors(path):
    for item in [*reversed(path.parents), path]:
        if item.is_symlink():
            raise SyncError(f"Refusing symbolic link: {item}")
        if item.exists() and item != path and not item.is_dir():
            raise SyncError(f"Expected a directory: {item}")


def fingerprint(path):
    check_ancestors(path)
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode):
        raise SyncError(f"Expected a regular file: {path}")
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    after = path.lstat()
    if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
        raise SyncError(f"File changed while being read: {path}")
    return {"sha256": digest.hexdigest(), "size": after.st_size, "executable": bool(after.st_mode & 0o111)}


def source_inventory(root):
    files = {}
    omitted = []
    for entry in git(root, "ls-files", "--stage", "-z").stdout.split(b"\0"):
        if not entry:
            continue
        metadata, raw_name = entry.split(b"\t", 1)
        mode, _, stage = metadata.split()
        name = relative_name(os.fsdecode(raw_name))
        if stage != b"0":
            raise SyncError(f"Resolve the Git merge conflict first: {name}")
        if name == MANIFEST:
            raise SyncError(f"{MANIFEST} is destination metadata and must not be tracked.")
        if excluded(name):
            omitted.append(name)
            continue
        if mode not in (b"100644", b"100755"):
            raise SyncError(f"Only regular tracked files may be mirrored: {name} (Git mode {mode.decode()})")
        actual = fingerprint(root / name)
        if actual["executable"] != (mode == b"100755"):
            raise SyncError(f"Executable permission differs from Git: {name}")
        files[name] = actual
    if not files:
        raise SyncError("No tracked source files. Stage and commit Clay before applying a sync.")
    return files, omitted


def load_baseline(destination):
    path = destination / MANIFEST
    if not path.exists():
        return {}, None
    fingerprint(path)
    raw = path.read_bytes()
    try:
        value = json.loads(raw)
        if value.get("schema_version") != 1 or not isinstance(value.get("files"), dict):
            raise ValueError("unsupported manifest structure")
        for name, item in value["files"].items():
            relative_name(name)
            if name == MANIFEST or not isinstance(item, dict):
                raise ValueError("invalid file entry")
            if not re.fullmatch(r"[0-9a-f]{64}", item.get("sha256", "")):
                raise ValueError("invalid SHA-256")
            if type(item.get("size")) is not int or item["size"] < 0 or type(item.get("executable")) is not bool:
                raise ValueError("invalid file size or mode")
            if set(item) != {"sha256", "size", "executable"}:
                raise ValueError("unexpected file metadata")
        return value["files"], raw
    except (ValueError, TypeError, AttributeError) as error:
        raise SyncError(f"Cannot trust existing {MANIFEST}: {error}") from error


def destination_inventory(destination, expected_directories):
    check_ancestors(destination)
    if not destination.exists():
        return {}, []
    if not destination.is_dir():
        raise SyncError(f"Destination is not a directory: {destination}")
    files = {}
    unexpected_directories = []
    for directory, directories, filenames in os.walk(destination, followlinks=False):
        for name in directories:
            path = Path(directory) / name
            check_ancestors(path)
            relative = path.relative_to(destination).as_posix()
            if relative not in expected_directories:
                unexpected_directories.append(relative)
        for name in filenames:
            path = Path(directory) / name
            relative = path.relative_to(destination).as_posix()
            item = fingerprint(path)
            if relative != MANIFEST:
                files[relative] = item
    return files, unexpected_directories


def parents_of(names):
    return {str(parent) for name in names for parent in PurePosixPath(name).parents if str(parent) != "."}


def plan_sync(expected, baseline, actual, unexpected_directories):
    conflicts = [f"Unexpected destination directory: {name}" for name in unexpected_directories]
    changes = []
    for name in sorted(set(baseline) - set(expected)):
        conflicts.append(f"Obsolete tracked file requires explicit reconciliation (never deleted automatically): {name}")
    for name in sorted(set(actual) - set(expected) - set(baseline)):
        conflicts.append(f"Unexpected destination file: {name}")
    for name, wanted in sorted(expected.items()):
        current = actual.get(name)
        if current == wanted:
            continue
        if name in baseline and current is None:
            conflicts.append(f"Previously mirrored file was removed from destination: {name}")
        elif current is None:
            changes.append(("add", name))
        elif current == baseline.get(name):
            changes.append(("update", name))
        else:
            conflicts.append(f"Destination differs from both source and recorded baseline: {name}")
    return changes, conflicts


def ensure_current(path, expected):
    check_ancestors(path)
    current = fingerprint(path) if path.exists() else None
    if current != expected:
        raise SyncError(f"File changed since preflight; no overwrite attempted: {path}")


def atomic_write(path, data, executable=False, previous=None):
    check_ancestors(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    check_ancestors(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix=".clay-sync-", dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.chmod(0o755 if executable else 0o644)
        ensure_current(path, previous)
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, help="Mirror folder; otherwise discover the sole Proton Drive [projects]/clay folder.")
    parser.add_argument("--apply", action="store_true", help="Copy after preflight; requires a clean, committed source repository.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    repository = Path(os.fsdecode(git(root, "rev-parse", "--show-toplevel").stdout).strip()).resolve()
    if repository != root:
        raise SyncError("Run the script inside the canonical Clay repository, not a nested copy.")
    requested_destination = args.destination if args.destination is not None else discover_destination()
    destination = Path(os.path.abspath(requested_destination.expanduser()))
    check_ancestors(destination)
    if not destination.parent.is_dir():
        raise SyncError(f"Destination parent must already exist; confirm the configured Proton folder: {destination.parent}")
    if destination == root or destination in root.parents or root in destination.parents:
        raise SyncError("Source and destination must be separate, non-nested folders.")

    dirty = bool(git(root, "status", "--porcelain=v1", "--untracked-files=all").stdout)
    head = git(root, "rev-parse", "--verify", "HEAD", check=False)
    commit = head.stdout.decode().strip() if head.returncode == 0 and not dirty else None
    if args.apply and commit is None:
        raise SyncError("Apply requires a clean Git repository with a commit, including no untracked files. Commit intended changes first.")

    expected, omitted = source_inventory(root)
    baseline, manifest_bytes = load_baseline(destination)
    directories = parents_of(set(expected) | set(baseline))
    actual, unexpected = destination_inventory(destination, directories)
    changes, conflicts = plan_sync(expected, baseline, actual, unexpected)
    report = {
        "mode": "apply" if args.apply else "dry-run",
        "destination": str(destination),
        "source_commit": commit,
        "source_clean": not dirty,
        "tracked_files": len(expected),
        "excluded_tracked_files": omitted,
        "changes": [{"action": action, "path": name} for action, name in changes],
        "conflicts": conflicts,
        "cloud_upload_verified": False,
    }
    if conflicts:
        print(json.dumps(report, indent=2))
        return 2
    if not args.apply:
        report["result"] = "Preflight passed; no files written."
        print(json.dumps(report, indent=2))
        return 0

    # Repeat the complete preflight immediately before the first mutation.
    refreshed, unexpected = destination_inventory(destination, directories)
    if refreshed != actual or unexpected:
        raise SyncError("Destination changed after preflight; retry after reconciling it.")
    destination.mkdir(parents=True, exist_ok=True)
    for _, name in changes:
        ensure_current(destination / name, actual.get(name))
        data = (root / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected[name]["sha256"]:
            raise SyncError(f"Source changed during sync: {name}; rerun after committing.")
        atomic_write(destination / name, data, expected[name]["executable"], actual.get(name))
        if fingerprint(destination / name) != expected[name]:
            raise SyncError(f"Verification failed: {name}")

    verified, unexpected = destination_inventory(destination, parents_of(expected))
    if verified != expected or unexpected:
        raise SyncError("Final destination verification failed; the prior baseline remains intact.")
    if git(root, "status", "--porcelain=v1", "--untracked-files=all").stdout or git(root, "rev-parse", "HEAD").stdout.decode().strip() != commit:
        raise SyncError("Source changed during sync; the prior baseline remains intact. Commit and rerun.")
    _, current_manifest = load_baseline(destination)
    if current_manifest != manifest_bytes:
        raise SyncError("Destination manifest changed during sync; refusing to replace it.")
    manifest = {"schema_version": 1, "source_commit": commit, "files": expected}
    encoded = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    if encoded != manifest_bytes:
        previous_manifest = fingerprint(destination / MANIFEST) if manifest_bytes is not None else None
        atomic_write(destination / MANIFEST, encoded, previous=previous_manifest)
    if (destination / MANIFEST).read_bytes() != encoded:
        raise SyncError("Manifest verification failed.")
    report["result"] = "Local mirror verified against all source hashes. Proton cloud upload is not verified by this script."
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (SyncError, OSError) as error:
        print(f"Sync refused: {error}", file=sys.stderr)
        sys.exit(2)
