# Keeping Clay source and private writing in sync

Clay has two separate storage workflows. The canonical Git repository, GitHub, and Proton Drive `[projects]/clay` contain code and release documentation. Private writing and synchronization history belong in the app's local storage and its dedicated personal iCloud Drive folder, outside source repositories and `[projects]`.

The owner confirmed the same personal iCloud Drive account on the iPhone, Mac, and Windows PC. Build 4's local validation and TestFlight delivery passed, and the owner confirmed its phone installation. The Mac connected to **iCloud Drive/Clay** through foreground user interaction; Settings showed **Storage: Clay** and **Shared folder updated**. The folder contains `ClaySync/format.json`, `Records`, and `Exports`, with zero records, so no private writing was transferred. The earlier disabled Mac Connect button came from background automation rather than an app defect. The phone's regular-folder connection failed; build 5 includes a path-alias validation fix, with delivery still in progress. Phone connection, Windows receipt, and an end-to-end cloud check remain pending. `Release/project-destinations.json` records both workflows and their separate verification states without account-specific home paths or credentials.

## Source workflow

GitHub's existing public visibility is preserved. Proton's exact source subfolder remains `[projects]/clay`; the sync script discovers the configured account root locally. Build 4 source `2cc916f3989956c75d73d08cdff42b7cd9979092` is pushed, its 63-file local mirror was verified, and the Proton web manifest was observed at that commit. This cloud check inspected the manifest rather than every remote file byte. Build 5 source and updated delivery documentation still await publication and mirroring.

After every completed Clay edit:

1. Fetch GitHub and inspect `git status`, the current branch, and incoming/outgoing commits. Reconcile remote changes without discarding local work. Never force-push or reset away another change to make the copies agree.
2. Run checks appropriate to the change, including `python3 scripts/validate_source.py` in the Git checkout. Review and stage only the intended source changes, then run `python3 scripts/check-source-privacy.py --staged` before committing. The default privacy check inspects both index bytes and tracked working files; `--staged` checks what Git would commit. It catches known Clay runtime folders, UUID document/record names, and document headers without printing contents. It cannot identify arbitrary private prose. Keep personal writing, libraries, SyncJournal, ClaySync records/exports, signing files, dependencies, and build output outside source control.
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

## Source mirror safeguards

The default is a dry run with no filesystem changes. Apply requires a clean repository with a commit, including no untracked files. Only regular Git-tracked files are eligible. Git internals, build/cache directories, app library/recovery directories, and known signing/credential file types are excluded even if accidentally tracked; inspect the reported exclusions and remove sensitive material from Git separately.

The destination's `.clay-sync-manifest.json` records the source commit, SHA-256 digest, size, and executable permission for every mirrored file. A first copy accepts existing files only when they already match the source. Later copies update a destination file only when it matches the current source or its recorded prior version. Files are replaced atomically, and every mirrored file is verified before the baseline is updated.

Unexpected destination files, destination edits, removed prior files, unexpected directories, and symbolic links stop the sync. No file is deleted automatically. If a source rename or deletion makes a previously mirrored path obsolete, the script reports it and refuses to apply. Preserve and compare both copies first; explicitly reconcile obsolete files and their manifest entries only after confirming what should remain. Never erase a conflict or the baseline merely to silence the check.

A failure during copying can leave some files at the new version while retaining the prior baseline. The script reports failure. A rerun with the same clean source accepts files already matching that source and can finish safely. Keep the source commit unchanged until that interrupted sync is reconciled.

Avoid editing source directly inside the Proton mirror or running multiple syncs concurrently. Bring intentional mirror edits back into the canonical repository, review and commit them, then reconcile the mirror. The script does not perform bidirectional merges, Git pushes, or background monitoring.

## Private writing workflow — builds 4 and later

Use the same dedicated **Clay** folder in personal iCloud Drive on each device. On Mac choose it in **Clay → Settings → Private library**; on iPhone use the library's **gear → Private library**. The picker grants access only to the selected folder. Connecting retains the local library and exchanges its history with that folder. Disconnecting retains both local and shared files.

The app saves an immutable local history in `Clay/SyncJournal` before updating its `Clay/Library` Markdown copies. Offline writing therefore does not depend on provider access. While active, Clay checks for shared changes and retries when the folder becomes available. Concurrent content is preserved as conflict copies; deletion records retire the original identity instead of treating a temporarily absent cloud file as a deletion.

| Private path inside the selected folder | Purpose |
| --- | --- |
| `ClaySync/Records` | Immutable synchronization records, including writing history and deletions; preserve these for recovery |
| `ClaySync/Exports/<deviceID>` | A device's readable Markdown copies and current snapshot manifest |

Windows can receive the private folder through iCloud Drive and read the Markdown exports. The manifest identifies the current snapshot; older unlisted exports may remain. These are derived reading copies: editing them does not update Clay. No Windows native application is included. Do not hand-edit synchronization records or place private folders in GitHub/source mirrors.

“Shared folder updated” means local provider access succeeded. It does not prove upload completion or arrival on another device. The build 4 Mac connection and empty private-folder initialization are verified. Record phone connection, a cross-device edit/relaunch, Windows reception, and any restore check separately; these remain pending. Build 5 also needs verification that the installed Mac app restores its saved folder access.

Proton personal-data backups are a separate workflow from this source mirror. This release creates no PC backup jobs, destination, retention policy, or schedule. Only a confirmed personal iCloud/PC folder scope may feed an independently verified PC → Proton backup; never include work-Mac folders, whole drives, or all of iCloud Drive. Existing external backup setup has not been verified by this release.
