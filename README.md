# Clay 0.1

A native writing app for macOS and iPhone, with a deliberate distinction between **Scratchpads** and **Pieces**. Both use the same editor. Moving a document changes its section while keeping its identity and writing intact.

## Current release — 0.1.0 (3)

Clay shares the app family's neutral light/dark surfaces, PP Neue Montreal interface type, and PP Neue York writing type. Build 3 tightens the Mac sidebar signature and adds a branded Settings header with the Clay mark, maker byline, and version. Scratchpads/Pieces colors, editor layout, and System/Light/Dark behavior are preserved.

The App Store Connect/TestFlight name is **Clay by Briggs Kellogg**. The bundle ID, installed Clay.app name, and writing location remain unchanged. Both native Debug builds and Release archives passed. Build 3 is installed and visually checked on the Mac, with System appearance selected. TestFlight delivery is in progress.

Release destinations and the source-only Proton scope are recorded in `Release/project-destinations.json`. Runtime writing sync, Windows archives, and scheduled personal-data backups are not configured by this release.

## Previous delivery history

This package contains the first native SwiftUI source implementation, a shared persistence package, an Xcode project with two app targets, tests, and Mac installation / TestFlight upload scripts.

**0.1.0 (2)** adds a saved **System / Light / Dark** appearance preference. Source validation, macOS/iOS Debug builds, and both Release archive builds passed. Build 2 is installed at `/Applications/Developer/Clay.app` with its signature verified. Mac switching, return to System, and Dark persistence across quit/relaunch passed; the final preference was restored to System. On the iOS simulator, the new gear and live System appearance changes were verified. Opposing Light/Dark overrides passed using temporary launch arguments; live Settings-sheet selection/reset remains pending. Both build 2 uploads succeeded at **5:36 PM America/Phoenix on 2026-11-08**; both completed Apple processing and were assigned to the internal Briggs TestFlight group. The update is available to the existing tester; physical-iPhone installation of build 2 has not yet been confirmed.

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

The initial library is empty. There is no seeded sample writing, telemetry, account sign-in, cloud sync, collaboration, or server. **The Mac and phone libraries are separate in this version.** Transfer writing between them with Markdown export/import.

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

The [App Store Connect record](https://appstoreconnect.apple.com/apps/6832381528/distribution) is **Clay by Briggs Kellogg** (app ID `6832381528`), with bundle ID `com.briggskellogg.clay` and iOS/macOS platforms. The installed app is still named **Clay**. Both processed 0.1.0 (1) builds were assigned to the internal Briggs testing group through manual distribution. The appearance update, 0.1.0 (2), also completed processing and is assigned to Briggs on both platforms. See **DISTRIBUTION.md** for the release configuration and future upload steps.

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
```

Regenerate the project after adding or removing Swift app files. The generator owns the Xcode project, shared schemes, platform Info plists, entitlements, and privacy manifest. It never changes `Config/Signing.local.xcconfig`. The validator checks project wiring and file syntax, not Swift type checking or app behavior.

## Writing and recovery

The active library is the app's Application Support directory plus `Clay/Library`. On sandboxed macOS builds, this is inside the app's container; **Writing → Show Library in Finder** opens the actual location. On iOS it is inside the application container.

Each active document is a UUID-named `.md` file. Its first HTML comment stores versioned, base64-encoded metadata; the body follows unchanged. Titles, section, pin state, collections and dates live in that comment. The encoding prevents titles containing `-->` from breaking the header. Dates use Foundation's reference-date representation to retain precision.

Before replacing an existing document, Clay saves its prior bytes to `Backups/<uuid>.md`. This keeps one previous revision, not a full version history. If preserving that prior copy fails, the active file is not replaced. A successful Trash action first saves current in-memory text and then moves the file into `Trash/`; pending older saves cannot recreate it during that session.

To recover a Mac document, use **Writing → Show Deleted Documents in Finder** or open `Backups` through the library folder, then import the desired `.md` file into Clay. Import creates a new document identity and leaves the recovery source intact. Do not rename recovery files into the active library while Clay is running.

Markdown export removes Clay's metadata and includes the document title as a `#` heading unless the body already starts with that exact heading. Plain Markdown import takes its title from the filename and preserves the entire file as the editing body. Import is a copy operation, not editing an external file in place; files must be UTF-8 and no larger than 10 MiB.

## Project map

| Path | Purpose |
| --- | --- |
| `Apps/Shared` | Observable store, editor, reading preview, theme, import/export document type |
| `Apps/macOS` | Mac window, commands, file actions, quit-time save handling |
| `Apps/iOS` | Phone/iPad navigation, library, file handling, background-save lifecycle |
| `Sources/ClayCore` | Foundation models, Markdown codec, serialized disk repository |
| `Tests/ClayCoreTests` | Persistence and file-format regressions |
| `Resources` | Original Clay artwork, fonts, asset catalogs, privacy manifest |
| `Config` | Bundle settings, platform metadata, Mac sandbox entitlements |
| `scripts` | Asset packaging, validation, builds, installation, archives, uploads |

## Before relying on this beta

Complete the remaining native checks in **TEST_REPORT.md**. The basic Mac quit/relaunch check passed, but immediate-quit stress cases, save failures, and iPhone background saving still need acceptance testing before relying on this first build for irreplaceable work. The reading view supports basic headings, paragraphs, bullets, block quotes, inline emphasis/links, rules and fenced code; advanced Markdown features such as tables and nested lists are not fully rendered. The original text remains editable and exportable.

The app is available for internal TestFlight testing. No external beta review or public App Store release was requested, and no notarization result is recorded. The remaining runtime checks in `TEST_REPORT.md` still apply.
