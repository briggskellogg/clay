# Installing and distributing Clay 0.1

## Current candidate — 0.1.0 (5)

Build 5 updates the app-family signature and icons with an exact crop of the original Clay symbol and the byte-preserved gold maker's mark. It also fixes private-folder validation for file-provider paths containing an ancestor alias. The 19 focused path cases and actual transport/Store regression checks passed. Both native Release archives passed; uploads are pending, and build IDs, processing, Briggs assignment, Mac installation/bookmark restoration, and physical-phone build 5 installation/connection remain pending. The candidate's source commit is not yet recorded.

The Mac icon is transparent. iOS has a transparent Dark appearance icon with an opaque Any appearance fallback. No generated replacement artwork is used. The App Store Connect name remains **Clay by Briggs Kellogg**.

## Delivered beta — 0.1.0 (4)

Build 4 adds a private selected iCloud Drive folder, offline revision history, conflict copies, durable deletion records, and readable per-device Windows exports. The 38-test core suite, synthetic Store/transport integration, privacy checks, both Debug builds, and Release archives passed. Source `2cc916f3989956c75d73d08cdff42b7cd9979092` produced the uploaded builds. Both uploads succeeded at **9:28 PM America/Phoenix on November 8, 2026**, completed processing, and are **Testing** in Briggs (**1 Tester / 8 Builds**). No duplicate invitation was sent.

The development-signed Mac app is installed at `/Applications/Developer/Clay.app`; launch and Settings version 0.1.0 (4) were verified after the owner accepted the updated-version prompt. Foreground user interaction connected the Mac to personal **iCloud Drive/Clay**, with **Storage: Clay** and **Shared folder updated** shown in Settings. The private folder was initialized with `format.json`, `Records`, and `Exports`; zero records were present, so no private writing was transferred. The previously disabled Mac Connect button was caused by background automation, not app code.

The owner confirmed physical-phone build 4 installation, but its regular-folder connection failed. Build 5 includes the corresponding path-alias validation fix. Phone connection, Windows receipt, and an end-to-end cloud check remain pending. Windows exports are derived reading copies; editing them does not update Clay. See TEST_REPORT.md for precise evidence.

## Delivered release — 0.1.0 (3)

The shared App Store Connect/TestFlight record was renamed to **Clay by Briggs Kellogg** on November 8, 2026. App ID, bundle ID, tester group, and the installed Clay.app name remain unchanged. Build 3 finalizes the compact Mac sidebar and branded Settings. Both Debug builds and Release archives passed, and the Mac installation and appearance checks passed. Both iOS and macOS build 3 uploads succeeded at **8:41 PM America/Phoenix on November 8, 2026**. Both completed Apple processing and are assigned to the internal **Briggs** group, with **Testing** status and 90-day expiry. The group shows **1 Tester / 6 Builds**; no duplicate invitation was sent. Physical-iPhone installation of build 3 has not yet been confirmed.

## Appearance release — 0.1.0 (2)

**0.1.0 (2)** adds the saved System/Light/Dark appearance preference. Source validation, both Debug builds, and both Release archive builds passed. Build 2 is installed at `/Applications/Developer/Clay.app` with its signature verified. Mac Light/Dark switching, Dark → System restoration to OS light, and Dark persistence across quit/relaunch passed; the final preference is System. The iOS simulator showed the new gear and followed an OS dark-mode change in System mode. Opposing Light/Dark overrides passed using temporary launch arguments, which were cleared afterward; live Settings-sheet selection/reset remains pending. Both build 2 uploads succeeded at **5:36 PM America/Phoenix on 2026-11-08**; both completed Apple processing and were assigned to the internal Briggs group. Physical-iPhone installation of build 2 has not yet been confirmed.

## Initial release history — 0.1.0 (1)

Validated on the owner's Mac on **2026-11-08**: all 25 XCTest methods passed; macOS Debug/Release, iOS simulator Debug, and iOS device Release compilation passed. Icon generation now handles RGB row stride correctly; the original Clay artwork and Bard typography remain unchanged.

A signed Mac archive is valid and the exported Mac `.pkg` is verified. With no registered development devices, an unsigned iOS archive was exported using `app-store-connect` and an explicit `teamID`; the resulting signed `.ipa` is verified.

The initial Mac installation at `/Applications/Developer/Clay.app` passed signature verification and reopening. The Mac smoke check passed: empty library, new Scratchpad with Unicode title/text, move to Pieces and back, and quit/reopen with the full text intact and Saved status. The temporary verification document was moved to recoverable Trash, leaving the active library empty. The iPhone 17 Pro simulator on iOS 26.2 booted, installed, and launched Clay; visual inspection confirmed the empty library, creation/import controls, and Scratchpads/Pieces tabs. The owner confirmed physical-iPhone installation and launch of **build 1** through TestFlight on **2026-11-08**. iOS editing/persistence and the other acceptance scenarios in `TEST_REPORT.md` remain pending.

Both iOS and macOS **0.1.0 (1)** uploaded successfully at **5:09 PM America/Phoenix on 2026-11-08** and completed Apple processing with a 90-day TestFlight expiry. Both builds were assigned to the internal **Briggs** group using manual distribution. The verified November 8 snapshot showed **1 Tester / 2 Builds**, with `briggs@kellogg.co` as **Invited**. The owner subsequently confirmed successful installation and launch on a physical iPhone.

For the initial release, the feedback email and beta description were saved; that original description identified local-only writing. The build 4 beta description has since been updated and saved to explain optional private sync and Windows reading copies. No external beta review or public App Store release was requested or performed.

## Build and distribution configuration

| Item | Current value / action |
| --- | --- |
| Product | Clay |
| App Store Connect name | Clay by Briggs Kellogg; the installed app name remains Clay |
| App Store Connect app ID | [`6832381528`](https://appstoreconnect.apple.com/apps/6832381528/distribution) |
| Primary language / SKU | English (U.S.) / `clay-01` |
| Marketing version | 0.1.0 |
| Current build number | 5 — branding and private-folder path fix candidate; build 4 is the latest verified Testing release |
| Bundle ID | `com.briggskellogg.clay`, used for the verified signed exports |
| Platforms | iOS and macOS in one App Store Connect app record |
| Deployment targets | iOS 17+, macOS 14+ |
| iOS upload toolchain | Xcode 26+ with iOS 26 SDK+ under Apple's current requirement |
| Signing | Verified with the configured Apple Developer team; keep team selection and signing credentials local |
| TestFlight group | Briggs, internal testing, manual distribution; iOS and macOS 0.1.0 builds 1, 2, 3 and 4 assigned |
| TestFlight recipient | `briggs@kellogg.co` — Invited on November 8, 2026 |
| Feedback contact and beta description | Saved in App Store Connect; current description explains optional private sync and Windows reading copies |

Both targets currently share the bundle identifier so they can use a multiplatform App Store Connect record. Apple documents that multiple platforms can be added under one record with the same identifier. [Apple: Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)

The newer SDK requirement concerns what builds the app, while the deployment target is the oldest OS it supports. Since April 28, 2026, mobile uploads require Xcode 26 and the relevant version-26 SDK or newer. [Apple: Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)

## 1. Build and verify locally

Open full Xcode, finish component setup, and select it as the command-line toolchain. From this folder:

```bash
bash scripts/build.sh macos
bash scripts/build.sh ios
```

Each script first prepares app icons from the supplied original logo, runs the core tests, then builds the relevant application without distribution signing. These build checks passed on 2026-11-08. The iOS command builds for a simulator; simulator launch and initial UI inspection passed, and the owner confirmed physical-iPhone installation and launch. iOS editing, persistence, accessibility, and other behavior checks remain as listed in `TEST_REPORT.md`.

Install the Mac build using `Install Clay.command` or `bash scripts/install-mac.sh`. The installer uses ad-hoc signing for the local app, preserves an older installation, and opens the installed result. It creates and uses `/Applications/Developer`, or `~/Applications/Developer` when `/Applications` is not writable. This is a local development build, not a notarized download for general distribution.

## 2. Configure the Apple team

In Xcode, add the Apple account and choose the intended team for both Clay targets under Signing & Capabilities. Keep automatic signing enabled. A paid Apple Developer Program team is required for TestFlight distribution. Xcode can manage the corresponding signing assets once the account and team are available. [Apple: Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

To keep signing selection out of generated project files, copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig` and replace `YOURTEAMID` with the team's identifier. That local file is ignored by Git. Alternatively, pass a team to the archive command as an environment variable:

```bash
CLAY_TEAM_ID=YOURTEAMID bash scripts/archive.sh ios
```

This is an identifier, not a signing key. Use Xcode and the Mac's Keychain for credentials. Do not paste private keys or passwords into project files or chat.

If the bundle identifier needs to change, edit `CLAY_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig` and reconcile the Apple app record and provisioning before uploading. Both targets inherit it.

## 3. Use the existing App Store Connect record

Use [Clay by Briggs Kellogg, app ID 6832381528](https://appstoreconnect.apple.com/apps/6832381528/distribution) for subsequent releases. The record contains both iOS and macOS, bundle ID `com.briggskellogg.clay`, primary language English (U.S.), and SKU `clay-01`. Keep these identities consistent with the Xcode configuration. The installed app's display name remains Clay.

## 4. Archive and upload

For iPhone:

```bash
bash scripts/archive.sh ios
bash scripts/upload-testflight.sh ios
```

For Mac TestFlight:

```bash
bash scripts/archive.sh macos
bash scripts/upload-testflight.sh macos
```

The archive command runs the core tests before archiving and allows Xcode to update provisioning. Archives go to `build/Clay-iOS.xcarchive` and `build/Clay-macOS.xcarchive`. The upload command uses `xcodebuild -exportArchive` with automatic signing and the `app-store-connect` upload method. A valid team and account must already be configured; no credentials are embedded in the scripts.

The successful local iOS distribution path used an unsigned generic-device Release archive, followed by App Store Connect export with an explicit team ID. This avoided requiring a development-device provisioning profile on a team with no registered devices. The export produced a signed IPA; it did not install or run the app on a phone. The upload script supports `CLAY_ARCHIVE_PATH` for an existing archive and `CLAY_TEAM_ID` to include `teamID` in its export options. Keep these local values out of the repository.

For an archive outside the script's default location, supply its absolute path and the configured team's identifier:

```bash
CLAY_ARCHIVE_PATH='/absolute/path/to/Clay-iOS.xcarchive' \
CLAY_TEAM_ID=YOURTEAMID \
bash scripts/upload-testflight.sh ios
```

Omit `CLAY_ARCHIVE_PATH` to use `build/Clay-iOS.xcarchive` or `build/Clay-macOS.xcarchive`, according to the platform argument. `CLAY_TEAM_ID` is optional when Xcode can determine the correct team from the archive; the verified unsigned-iOS-archive export required it explicitly.

In Xcode's Organizer, the equivalent path is Archive → Distribute App → App Store Connect → Upload. After the upload succeeds, wait for Apple's processing and inspect any validation messages. A successful command is not evidence that a build is already available to testers. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)

The privacy manifest declares no collected data or tracking and declares app-private UserDefaults use for editor preferences with reason `CA92.1`. The optional selected-folder workflow stores writing in the owner's private cloud folder. Re-evaluate the manifest if data collection, analytics, or third-party SDK behavior changes. [Apple: Required-reason API types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

## 5. Internal testing and invitation

Internal testing is configured in the **Briggs** group with manual build distribution. Both processed **0.1.0 (1)** builds were assigned; the verified November 8 snapshot showed **1 Tester / 2 Builds** and `briggs@kellogg.co` as **Invited**. In response to the TestFlight installation instruction, the owner reported **“Installed and opened”** on November 8, 2026, confirming physical-iPhone installation and launch of build 1. Both build 2 uploads completed processing and are also assigned to Briggs; no duplicate invitation was sent. Editor, persistence, background-save, and accessibility checks remain pending.

For later builds, wait for processing and assign the new iOS/macOS builds to Briggs manually. Internal testers need the appropriate App Store Connect account and app access. [Apple: Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)

No external beta review or public App Store release was requested or performed. The upload scripts do not send invitations; this invitation and group assignment were completed separately in App Store Connect.

## Suggested beta information

**Description:** Clay is a quiet writing app with separate spaces for scratchpads and finished pieces. Write in a native editor, move a document between those spaces without duplicating it, and import or export Markdown. Optionally connect the same private iCloud Drive folder on Mac and iPhone; Windows can read the exported snapshots through iCloud Drive.

**What to test:** Open Clay → Settings on Mac or the library gear on iPhone; switch System, Light, and Dark; verify the choice persists after reopening and System follows device appearance changes. Check the new symbol, name, and maker placement in both appearances. Connect the same dedicated private iCloud Drive/Clay folder on Mac and iPhone, then verify a new scratchpad arrives on the other device, survives reopening, and appears in Windows' readable exports. Test offline edits and concurrent changes. Edit, pin and organize a document; move it to Pieces and back; export and reimport Markdown; quit/relaunch on Mac; background/reopen on iPhone; verify that the last edit persists and save failures are visible. Check the editor with the keyboard open, larger text, and VoiceOver.

**Known limitations:** Writing stays local until a private folder is connected. Phone connection and end-to-end cloud propagation still need verification. Windows exports are reading copies; editing them does not import changes into Clay, and there is no Windows native app. An iPhone Trash recovery screen is not included. The Markdown reading view implements a basic subset.
