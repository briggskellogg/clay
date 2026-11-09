# Clay 0.1

A native writing app for macOS and iPhone, with a deliberate distinction between **Scratchpads** and **Pieces**. Both use the same editor. Moving a document changes its section while keeping its identity and writing intact.

## Delivered beta — 0.1.0 (6)

Build 6 keeps the last sync result steady in Settings and uses a small pulsing dot only while activity is running. Reduce Motion uses a static indicator. Errors stay visible during retries, including connection failures before a folder is connected. Background passes no longer flash the controls between enabled and disabled; changing or disconnecting the folder waits for the active pass to finish.

Both native Release archives passed. The 40 tracked archive inputs match source `f80acaabf98a44af34e0cb5e44ae88fea3a06f71`, and all 12 generated inputs match their captured hashes. Source validation, the focused Store activity/folder-transition checks, and the existing full Store integration suite passed. The development-signed Mac build 6 is installed at `/Applications/Developer/Clay.app` with its strict signature verified and the previous app preserved. Settings version 6, saved private-folder access, the existing phone-edited note with Saved status, Light appearance, and return to System were verified. Sync Now completed without changing the settled Shared folder updated label or the enabled button states. The dot compiled and rendered; pulse timing was not captured frame by frame, and Reduce Motion still needs a direct runtime check. Both uploads succeeded on November 8, 2026 at 22:26:48.728 (iOS) and 22:26:54.657 (macOS), America/Phoenix. Both completed processing and are **Testing in Briggs (1 Tester / 12 Builds)**. The name remains **Clay by Briggs Kellogg**, the build 6 beta description is saved, and no new invitation was sent. Phone build 6 installation is unconfirmed. Build 5’s successful two-way Mac–iPhone synthetic sync check remains recorded separately; Windows reception is postponed by the owner.

## Previous beta — 0.1.0 (5)

Build 5 separates the original red Clay symbol from the lettering using an exact pixel crop of the supplied artwork. The app shows the symbol and **Clay** in the shared interface font at the top, with the original gold maker's mark in the lower corner. The 416 × 512 maker asset is preserved byte for byte. The Mac icon has a transparent background; iOS includes a transparent Dark icon and an opaque Any appearance fallback. See `ASSETS.md` and `DESIGN.md` for the artwork and layout details.

Build 5 also fixes private-folder validation when the file provider returns a path through an ancestor alias. All 19 focused path cases and the actual transport/Store regression checks passed. Both native Release archives passed. The 40 tracked native inputs match source `d106286c96bba138055b8c9a6c1582fe8c623fe1`, and all 12 generated inputs retained their captured hashes. The iOS upload succeeded at **10:05:53 PM** and macOS at **10:06:32 PM America/Phoenix on November 8, 2026**. Both completed processing and show **Testing** in **Briggs (1 Tester / 10 Builds)**. The TestFlight name is **Clay by Briggs Kellogg**; no new invitation was sent.

The development-signed Mac build 5 archive was installed at `/Applications/Developer/Clay.app` with its strict code signature verified before the build 6 update. Launch, Settings version 0.1.0 (5), the new branding, Light appearance, and returning to System passed visual checks. The existing private-folder bookmark restored after the update. A synthetic note saved successfully, with three immutable records and one matching Markdown export verified in personal iCloud Drive/Clay. The owner then confirmed physical-iPhone build 5 installation, connection to the same iCloud Drive/Clay folder, and receipt of the Mac-created synthetic note. The earlier phone connection error is resolved after the update. The phone edit subsequently appeared in the Mac app with Saved status, independently verifying the return direction. The synthetic Mac–iPhone sync check passed in both directions; the owner deferred the Windows receipt check.

## Previous beta — 0.1.0 (4)

Build 4 implements an optional private writing library shared through a folder selected in personal iCloud Drive. The 38-test core suite, synthetic Store/transport integration, privacy checks, both Debug builds, and Release archives passed. Both uploads completed at **9:28 PM America/Phoenix on November 8, 2026** and are **Testing** in the internal **Briggs** group (**1 Tester / 8 Builds**). The development-signed Mac app was installed at `/Applications/Developer/Clay.app`; launch and Settings version 0.1.0 (4) were verified before the build 5 update. The TestFlight name remains **Clay by Briggs Kellogg**.

The owner confirmed build 4 was installed on the physical iPhone. The Mac connected to the dedicated personal **iCloud Drive/Clay** folder after foreground user interaction; Settings showed **Storage: Clay** and **Shared folder updated**, and the private `ClaySync` folder contains `format.json`, `Records`, and `Exports`. Its initial record count was zero; build 5 later verified synthetic-note publication as recorded above. The earlier disabled Mac Connect button resulted from background automation rather than an app defect. The phone rejected a regular selected folder; the owner subsequently confirmed connection and Mac-note receipt after updating to build 5. The return edit was then independently observed in the Mac app with Saved status. Windows reception remains unverified.

GitHub and Proton Drive `[projects]/clay` hold source code and release documentation only. Private writing stays outside both destinations. Clay keeps an offline local library and an immutable `SyncJournal`, then exchanges writing revisions through the selected private folder. Concurrent versions become conflict copies; deletion records preserve history and prevent an old device from silently recreating a deleted original.

The shared folder contains `ClaySync/Records` for synchronization and `ClaySync/Exports/<deviceID>` for readable Markdown snapshots. Windows can find those files through iCloud Drive. **Editing an export does not import the change into Clay, and this release does not build a Windows application.** Each export manifest identifies that device's current snapshot; older unlisted export files may remain for recovery.

### Connect the private library

1. Use a dedicated **Clay** folder in personal iCloud Drive, outside Git repositories and Proton's `[projects]` source area.
2. On Mac, open **Clay → Settings → Private library** and choose that folder. On iPhone, open the library's **gear → Private library** and choose the same folder in iCloud Drive.
3. Keep Clay open for the initial exchange. It checks for updates while active and when brought to the foreground. **Sync Now** requests another check; offline edits stay local until the folder becomes available.
4. On Windows, read the matching iCloud Drive folder's `ClaySync/Exports/<deviceID>` snapshot. Keep `Records` intact; it contains the complete synchronization history rather than ordinary documents to edit by hand.

Selecting the folder connects the device's existing Clay writing without deleting its local copy. Disconnecting retains both copies. A status saying the shared folder was updated describes local provider access, not proof that another device has downloaded it. Mac-to-phone synthetic-note receipt is owner-confirmed, and the return phone edit was independently observed on Mac with Saved status. Windows reception remains postponed. This release creates no PC backup jobs or Proton personal-data backup schedule; any existing external backup setup still needs its own evidence.

Release destinations and verification states are recorded in `Release/project-destinations.json`. Build 6 source `f80acaabf98a44af34e0cb5e44ae88fea3a06f71` is pushed to GitHub. Its 67-file local Proton mirror was hash-verified, and the Proton web manifest was observed at that commit. This cloud check inspected the manifest rather than every remote file byte. Subsequent delivery-documentation commits follow the same source-sync workflow; the source mirror manifest records the latest mirrored commit. See `SYNC.md` for the separate source and private-data workflows.

## Delivered release — 0.1.0 (3)

Clay shares the app family's neutral light/dark surfaces, PP Neue Montreal interface type, and PP Neue York writing type. Build 3 tightens the Mac sidebar signature and adds a branded Settings header with the Clay mark, maker byline, and version. Scratchpads/Pieces colors, editor layout, and System/Light/Dark behavior are preserved.

The App Store Connect/TestFlight name is **Clay by Briggs Kellogg**. The bundle ID, installed Clay.app name, and writing location remain unchanged. Both native Debug builds and Release archives passed. Build 3 was installed and visually checked on the Mac, with System appearance selected. Both iOS and macOS build 3 uploads succeeded at **8:41 PM America/Phoenix on November 8, 2026**. Both completed Apple processing and are assigned to the internal **Briggs** group, with **Testing** status and 90-day expiry. The group shows **1 Tester / 6 Builds**; no duplicate invitation was sent. Physical-iPhone installation of build 3 has not yet been confirmed.

Build 3 did not implement runtime writing sync, Windows archives, or scheduled personal-data backups. The later private-library request is implemented separately in build 4 above.

## Previous delivery history

This package contains the first native SwiftUI source implementation, a shared persistence package, an Xcode project with two app targets, tests, and Mac installation / TestFlight upload scripts.

**0.1.0 (2)** adds a saved **System / Light / Dark** appearance preference. Source validation, macOS/iOS Debug builds, and both Release archive builds passed. Build 2 was installed at `/Applications/Developer/Clay.app` with its signature verified. Mac switching, return to System, and Dark persistence across quit/relaunch passed; the final preference was restored to System. On the iOS simulator, the new gear and live System appearance changes were verified. Opposing Light/Dark overrides passed using temporary launch arguments; live Settings-sheet selection/reset remains pending. Both build 2 uploads succeeded at **5:36 PM America/Phoenix on 2026-11-08**; both completed Apple processing and were assigned to the internal Briggs TestFlight group. The update is available to the existing tester; physical-iPhone installation of build 2 has not yet been confirmed.

For the initial **0.1.0 (1)** release on **2026-11-08**, all 25 XCTest methods passed; macOS Debug/Release, iOS simulator Debug, and iOS device Release builds compiled successfully. Icon generation was corrected for RGB row stride without changing the supplied artwork. A signed Mac archive, verified Mac distribution package, and verified signed iOS IPA were produced locally. Generated apps and distribution files are not committed to the source repository.

The initial Mac smoke check passed: an empty library, a new Scratchpad with Unicode title/text, moving it to Pieces and back, and quitting/reopening with the full text intact and a **Saved** status. The temporary verification document was then moved to recoverable Trash, leaving the active library empty. An iPhone 17 Pro simulator running iOS 26.2 also booted, installed, and launched Clay successfully; its empty library and Scratchpads/Pieces navigation were visually checked. The owner confirmed physical iPhone installation and launch of **build 1** through TestFlight on **2026-11-08**. iOS editing/persistence and the remaining acceptance checks are pending.

Both iOS and macOS **0.1.0 (1)** uploaded successfully at **5:09 PM America/Phoenix on 2026-11-08** and completed Apple processing with a 90-day TestFlight expiry. Both builds were assigned to the internal **Briggs** group; the verified November 8 snapshot showed **1 Tester / 2 Builds** and `briggs@kellogg.co` as **Invited**. The owner subsequently confirmed installation and launch on a physical iPhone. No external beta review or public App Store release was requested.

## First version

- macOS: a library sidebar, document list, native editor, and focus mode that hides the side panels.
- iPhone: separate Scratchpads and Pieces library destinations; opening a document gives it a full editor screen.
- Native text editing, a basic Markdown reading preview, word count, pins, collection labels, search, and font/size choices.
- Move to Pieces and Move to Scratchpads keep the same document.
- UTF-8 Markdown/plain-text import and Markdown export through native file pickers.
- Local autosave with explicit save status, retry on failure, atomic file replacement, and a recoverable previous copy.
- Trash preserves the latest content in a recovery folder. Mac recovery is available through Finder and reimport. A phone Trash/recovery screen is not included yet.
- Bard typography, pale navigation surfaces, a white writing canvas, adaptive dark colors, and Clay's supplied red artwork.
- Build 2: System, Light, and Dark appearance choices, saved per device. Open **Clay → Settings → Appearance** on Mac or the library's **gear → Appearance** on iPhone. System follows the device's appearance.
- Main destinations use colored filled symbols. Folders and utilities use neutral outlines. Pins fill amber when enabled. Selection also changes background and text weight, so color does not carry the meaning alone.

The initial library is empty, with no seeded sample writing, telemetry, app account, collaboration service, or app server. Builds 1–3 have separate Mac and phone libraries and use Markdown export/import for transfer. Build 4 adds the optional selected-folder synchronization described above; without a connected folder, writing remains on that device.

## Run and install on a Mac

Requirements: macOS 14 or newer and full Xcode 15 or newer. For current iOS TestFlight uploads, use Xcode 26 or newer with the iOS 26 SDK or newer. The app's minimum iOS version remains 17.

1. Unzip this folder into a writable location on the Mac.
2. Open Xcode once and complete its component setup. In Xcode's settings, select the installed Xcode under Locations → Command Line Tools if needed.
3. Double-click **Install Clay.command**. It runs the core tests, builds the Mac target, signs that local build ad hoc, and installs it into `/Applications/Developer/Clay.app` when `/Applications` is writable. Otherwise it uses `~/Applications/Developer/Clay.app`.
4. The installer opens Clay after a successful install. If an older app exists, it is kept under `~/Library/Application Support/Clay/InstallBackups`. The installer asks you to quit a running Clay before replacement; it does not terminate the process or remove writing.

This local installation path does not upload or publish anything, and does not require a paid Apple Developer team. It still requires a successful native build and tests. If Finder prevents launching the downloaded command file, inspect it in a text editor and run the equivalent command in Terminal from the unzipped Clay folder:

```bash
bash scripts/install-mac.sh
```

To work in Xcode, open **Clay.xcodeproj**. Select scheme **Clay-macOS** and My Mac, or **Clay-iOS** and an available iPhone simulator, then Run. The local **ClayCore** package is already linked. No package-manager install or external code dependency is needed.

## TestFlight

The [App Store Connect record](https://appstoreconnect.apple.com/apps/6832381528/distribution) is **Clay by Briggs Kellogg** (app ID `6832381528`), with bundle ID `com.briggskellogg.clay` and iOS/macOS platforms. The installed app is still named **Clay**. Both processed 0.1.0 (1) builds were assigned to the internal Briggs testing group through manual distribution. The appearance update, 0.1.0 (2), also completed processing and is assigned to Briggs on both platforms. Builds 3 through 6 are also processed and Testing in Briggs on both platforms. Build 6 is the latest delivered beta, with its Mac installation, saved private-folder access, and stable Settings checks verified. Phone build 6 installation is unconfirmed. Phone build 5 installation, folder connection, and Mac-to-phone note receipt are owner-confirmed; the return phone edit was independently observed on Mac with Saved status. Windows reception remains postponed. See **DISTRIBUTION.md** for the release configuration and future upload steps.

The upload scripts use an Apple account already configured in Xcode. No password, API key, signing key, or provisioning profile is bundled here. The non-secret developer team identifier is recorded in the release destination manifest. App Store Connect confirmed the invitation, and the owner subsequently reported successful physical-iPhone installation and launch. The scripts upload an existing archive; app-record setup and the invitation were completed separately in App Store Connect.

## Useful commands

Run these from the project folder on the Mac:

```bash
# Foundation model, format and persistence regression tests.
xcrun swift test

# Core tests plus a native development build.
bash scripts/build.sh macos
bash scripts/build.sh ios

# Archive for a team configured in Xcode or Config/Signing.local.xcconfig.
bash scripts/archive.sh ios
bash scripts/archive.sh macos

# Upload the corresponding existing archive to App Store Connect.
bash scripts/upload-testflight.sh ios
bash scripts/upload-testflight.sh macos
```

Optional project-maintenance commands (Python 3 only; not needed to build the checked-in project):

```bash
python3 scripts/generate_project.py
python3 scripts/validate_source.py
python3 scripts/check-source-privacy.py --staged
```

Regenerate the project after adding or removing Swift app files. The generator owns the Xcode project, shared schemes, platform Info plists, entitlements, and privacy manifest. It never changes `Config/Signing.local.xcconfig`. In a Git checkout, the validator checks known private-data formats in the index and tracked working files before checking project wiring and file syntax. It does not perform Swift type checking or app behavior checks. The privacy check recognizes known Clay files and paths; it cannot classify arbitrary private prose, so keep the private library outside source and review every staged change.

## Writing and recovery

The active local library is the app's Application Support directory plus `Clay/Library`. On sandboxed macOS builds, this is inside the app's container; **Writing → Show Library in Finder** opens the actual location. On iOS it is inside the application container. Build 4 adds `Clay/SyncJournal` beside the local library. That private journal is written before the visible Markdown copy, so local recovery does not depend on the cloud folder being available. It is not part of the source repository or Proton source mirror.

Each active document is a UUID-named `.md` file. Its first HTML comment stores versioned, base64-encoded metadata; the body follows unchanged. Titles, section, pin state, collections and dates live in that comment. The encoding prevents titles containing `-->` from breaking the header. Dates use Foundation's reference-date representation to retain precision.

Before replacing an existing Markdown copy, Clay saves its prior bytes to `Backups/<uuid>.md`. That folder keeps one previous copy; build 4's separate journal retains revision history. If preserving the prior copy fails, the active Markdown file is not replaced. Builds 1–3 save the latest text before moving a document into `Trash/`. Build 4 first records the latest text and deletion in the journal, then retires the local Markdown copy; a local-copy failure is reported while the journal retains the content. A deleted original identity stays retired across devices, and concurrent edits are retained as conflict copies with new identities.

To recover a Mac document, use **Writing → Show Deleted Documents in Finder** or open `Backups` through the library folder, then import the desired `.md` file into Clay. Import creates a new document identity and leaves the recovery source intact. Do not rename recovery files into the active library while Clay is running.

Markdown export removes Clay's metadata and includes the document title as a `#` heading unless the body already starts with that exact heading. Plain Markdown import takes its title from the filename and preserves the entire file as the editing body. Import is a copy operation, not editing an external file in place; files must be UTF-8 and no larger than 10 MiB.

## Project map

| Path | Purpose |
| --- | --- |
| `Apps/Shared` | Observable store, selected-folder sync transport, editor, reading preview, theme, import/export document type |
| `Apps/macOS` | Mac window, commands, file actions, quit-time save handling |
| `Apps/iOS` | Phone/iPad navigation, library, file handling, background-save lifecycle |
| `Sources/ClayCore` | Models, Markdown codec, disk repository, immutable sync journal |
| `Tests/ClayCoreTests` | Persistence, file-format, and sync-history regressions |
| `Resources` | Original Clay artwork, fonts, asset catalogs, privacy manifest |
| `Config` | Bundle settings, platform metadata, Mac sandbox entitlements |
| `scripts` | Asset packaging, validation, builds, installation, archives, uploads |

## Before relying on this beta

Complete the remaining native checks in **TEST_REPORT.md**. The basic Mac quit/relaunch check passed, but immediate-quit stress cases, save failures, and iPhone background saving still need acceptance testing before relying on this first build for irreplaceable work. The reading view supports basic headings, paragraphs, bullets, block quotes, inline emphasis/links, rules and fenced code; advanced Markdown features such as tables and nested lists are not fully rendered. The original text remains editable and exportable.

The app is available for internal TestFlight testing. No external beta review or public App Store release was requested, and no notarization result is recorded. The remaining runtime checks in `TEST_REPORT.md` still apply.
