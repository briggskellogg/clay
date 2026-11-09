# Installing and distributing Clay 0.1

## Current status

Validated on the owner's Mac on **2026-11-08**: all 25 XCTest methods passed; macOS Debug/Release, iOS simulator Debug, and iOS device Release compilation passed. Icon generation now handles RGB row stride correctly; the original Clay artwork and Bard typography remain unchanged.

A signed Mac archive is valid and the exported Mac `.pkg` is verified. With no registered development devices, an unsigned iOS archive was exported using `app-store-connect` and an explicit `teamID`; the resulting signed `.ipa` is verified. These are local distribution artifacts, not evidence of TestFlight availability.

Clay is installed at `/Applications/Developer/Clay.app`, with its signature verified and successful reopening confirmed. The Mac smoke check passed: empty library, new Scratchpad with Unicode title/text, move to Pieces and back, and quit/reopen with the full text intact and Saved status. The temporary verification document was moved to recoverable Trash, leaving the active library empty. Actual iPhone runtime testing and the other acceptance scenarios in `TEST_REPORT.md` remain pending.

Signed distribution files are exported and ready, and the owner explicitly approved upload. The iOS upload attempt failed because the App Store Connect app record for `com.briggskellogg.clay` is missing. Mac upload was not attempted because it requires the same record. No build has been accepted or uploaded; TestFlight processing, beta review, tester access, and invitation remain pending.

The App Store Connect browser session is not signed in. Owner sign-in is pending so the missing app record can be created and the authorized upload retried.

## Build and distribution configuration

| Item | Current value / action |
| --- | --- |
| Product | Clay |
| Initial marketing version | 0.1.0 |
| Initial build number | 1; increment for subsequent uploaded builds |
| Bundle ID | `com.briggskellogg.clay`, used for the verified signed exports |
| Platforms | iOS and macOS in one App Store Connect app record |
| Deployment targets | iOS 17+, macOS 14+ |
| iOS upload toolchain | Xcode 26+ with iOS 26 SDK+ under Apple's current requirement |
| Signing | Verified with the configured Apple Developer team; keep team selection and signing credentials local |
| TestFlight recipient | `briggs@kellogg.co` — explicitly confirmed by the owner on 2026-11-08; invitation not sent |
| Feedback contact | Set to an address the owner controls |

Both targets currently share the bundle identifier so they can use a multiplatform App Store Connect record. Apple documents that multiple platforms can be added under one record with the same identifier. [Apple: Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)

The newer SDK requirement concerns what builds the app, while the deployment target is the oldest OS it supports. Since April 28, 2026, mobile uploads require Xcode 26 and the relevant version-26 SDK or newer. [Apple: Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)

## 1. Build and verify locally

Open full Xcode, finish component setup, and select it as the command-line toolchain. From this folder:

```bash
bash scripts/build.sh macos
bash scripts/build.sh ios
```

Each script first prepares app icons from the supplied original logo, runs the core tests, then builds the relevant application without distribution signing. These build checks passed on 2026-11-08. The iOS command builds for a simulator; runtime checks in the simulator and on an actual iPhone still need to be completed as listed in `TEST_REPORT.md`.

Install the Mac build using `Install Clay.command` or `bash scripts/install-mac.sh`. The installer uses ad-hoc signing for the local app, preserves an older installation, and opens the installed result. It creates and uses `/Applications/Developer`, or `~/Applications/Developer` when `/Applications` is not writable. This is a local development build, not a notarized download for general distribution.

## 2. Configure the Apple team

In Xcode, add the Apple account and choose the intended team for both Clay targets under Signing & Capabilities. Keep automatic signing enabled. A paid Apple Developer Program team is required for TestFlight distribution. Xcode can manage the corresponding signing assets once the account and team are available. [Apple: Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

To keep signing selection out of generated project files, copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig` and replace `YOURTEAMID` with the team's identifier. That local file is ignored by Git. Alternatively, pass a team to the archive command as an environment variable:

```bash
CLAY_TEAM_ID=YOURTEAMID bash scripts/archive.sh ios
```

This is an identifier, not a signing key. Use Xcode and the Mac's Keychain for credentials. Do not paste private keys or passwords into project files or chat.

If the bundle identifier needs to change, edit `CLAY_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig` and reconcile the Apple app record and provisioning before uploading. Both targets inherit it.

## 3. Create the App Store Connect record

With an authorized App Store Connect role, create the Clay app record using the final bundle ID, primary language and a unique SKU. Add the second platform to the same record. Resolve any agreement the Account Holder is required to accept. The app record must exist before an upload. [Apple: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

This record is the current release blocker: the iOS upload attempt reported it missing for `com.briggskellogg.clay`. Complete owner sign-in and create the record before retrying iOS or attempting Mac upload.

## 4. Archive and upload

For iPhone:

```bash
bash scripts/archive.sh ios
bash scripts/upload-testflight.sh ios
```

For Mac TestFlight, if desired in addition to the Applications installation:

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

The privacy manifest declares no collected data or tracking and declares app-private UserDefaults use for editor preferences with reason `CA92.1`. This matches the included code; re-evaluate the manifest if analytics, synchronization or third-party SDKs are added. [Apple: Required-reason API types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

## 5. Invite the owner

The owner explicitly supplied `briggs@kellogg.co` for the TestFlight invitation on 2026-11-08. Use that address for the already-requested invitation once a signed build is processed and available. Mac/Xcode access and distribution signing are now verified; the recipient's tester role, processed build availability, and invitation remain to be completed and confirmed.

For an eligible App Store Connect account, add the owner to an internal testing group, make the processed build available to that group, and send the invitation. Internal testers must be App Store Connect users with appropriate app access. [Apple: Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)

If the chosen recipient is an external tester instead, supply the required beta information and submit the first external build for TestFlight review. Invite the tester after the build is available for that group. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

No invitation is sent by the supplied scripts. Record the actual build number and invitation result after completing the action; do not treat an upload as an invitation.

## Suggested beta information

**Description:** Clay is a quiet writing app with separate spaces for scratchpads and finished pieces. Write in a native editor, move a document between those spaces without duplicating it, and import or export Markdown.

**What to test:** Create a scratchpad; edit, pin and organize it; move it to Pieces and back; export and reimport Markdown; quit/relaunch on Mac; background/reopen on iPhone; verify that the last edit persists and save failures are visible. Check the editor with the keyboard open, larger text, light/dark appearance, and VoiceOver.

**Known limitation:** Libraries are local to each installation. Cross-device sync and an iPhone Trash recovery screen are not included in this beta. The Markdown reading view implements a basic subset.
