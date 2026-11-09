# Keeping Clay in sync

The canonical local Git repository is the working source. GitHub keeps its committed history; Proton Drive keeps a verified mirror of tracked source files. Scratchpads, Pieces, personal writing, app libraries, signing credentials, and generated builds are not part of this source mirror. This workflow does not add cross-device writing sync to the app.

The user's November 8, 2026 clarification confirms this existing source-only workflow: Proton Drive, `[projects]/clay`, and the corresponding GitHub repository. The broader cloud-sync discussion does not make personal-writing sync, iCloud integration, Windows backups, or new schedulers part of this release. Those destinations remain unconfigured.

See `Release/project-destinations.json` for the release destination map. Its Proton path is the exact project subfolder; the account-specific local root is resolved by the script and is not stored in this public repository. GitHub was verified as public on November 8, 2026; this workflow does not change its visibility.

After every completed Clay edit:

1. Fetch GitHub and inspect `git status`, the current branch, and incoming/outgoing commits. Reconcile remote changes without discarding local work. Never force-push or reset away another change to make the copies agree.
2. Run the checks appropriate to the change, review the diff, and commit the intended source changes. Keep signing files, personal writing, dependencies, and build output out of Git.
3. Push the committed branch to the corresponding Clay repository and verify the remote commit. A failed push means GitHub is still pending.
4. Preview the Proton mirror, inspect its report, then apply it:

   ```bash
   python3 scripts/sync-proton.py
   python3 scripts/sync-proton.py --apply
   ```

5. Confirm Proton Drive has finished uploading in its app or web interface before reporting the cloud copy as synchronized. The script verifies local bytes only; a successful local mirror is not proof of a completed cloud upload.

The script discovers existing Proton Drive accounts under the current user's `Library/CloudStorage` and uses `[projects]/clay` only when exactly one account contains a `[projects]` folder. If none or more than one qualifies, it stops and requires an explicit destination. For a different configured Proton folder, pass the same explicit destination to preview and apply:

```bash
python3 scripts/sync-proton.py --destination '/absolute/path/to/[projects]/clay'
python3 scripts/sync-proton.py --destination '/absolute/path/to/[projects]/clay' --apply
```

## What the script guarantees

The default is a dry run with no filesystem changes. Apply requires a clean repository with a commit, including no untracked files. Only regular Git-tracked files are eligible. Git internals, build/cache directories, app library/recovery directories, and known signing/credential file types are excluded even if accidentally tracked; inspect the reported exclusions and remove sensitive material from Git separately.

The destination's `.clay-sync-manifest.json` records the source commit, SHA-256 digest, size, and executable permission for every mirrored file. A first copy accepts existing files only when they already match the source. Later copies update a destination file only when it matches the current source or its recorded prior version. Files are replaced atomically, and every mirrored file is verified before the baseline is updated.

Unexpected destination files, destination edits, removed prior files, unexpected directories, and symbolic links stop the sync. No file is deleted automatically. If a source rename or deletion makes a previously mirrored path obsolete, the script reports it and refuses to apply. Preserve and compare both copies first; explicitly reconcile obsolete files and their manifest entries only after confirming what should remain. Never erase a conflict or the baseline merely to silence the check.

A failure during copying can leave some files at the new version while retaining the prior baseline. The script reports failure. A rerun with the same clean source accepts files already matching that source and can finish safely. Keep the source commit unchanged until that interrupted sync is reconciled.

Avoid editing source directly inside the Proton mirror or running multiple syncs concurrently. Bring intentional mirror edits back into the canonical repository, review and commit them, then reconcile the mirror. The script does not perform bidirectional merges, Git pushes, or background monitoring.
