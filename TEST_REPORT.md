# Clay 0.1 validation

Updated 2026-11-08 after native Mac and simulator testing and the owner's physical-iPhone installation/launch confirmation. This report distinguishes independently observed checks, owner-reported results, and remaining acceptance work.

## Quieter Settings activity — 0.1.0 (6) candidate

The implementation keeps the last sync result visible while a small activity dot pulses. Reduce Motion uses a static dot. Error details remain visible during retries and after a failed initial connection. Routine background activity no longer disables and re-enables the controls; folder changes and disconnection wait for the active sync pass before proceeding.

Both native Release archives passed, and all 52 captured input hashes remained unchanged. Source validation, the focused actual Store activity/folder-transition suite, and the existing full Store integration suite passed.

The exact development-signed Mac archive was installed at `/Applications/Developer/Clay.app`; strict signature verification passed, and the prior app and private data were preserved. Settings version 6 restored the same private-folder bookmark and the existing phone-edited synthetic note with Saved status. Light appearance and return to System visually passed; the final setting is System. Sync Now completed with the same Shared folder updated label and enabled button states. The activity-dot view compiled and rendered, but pulse timing was not captured frame by frame. Reduce Motion and error presentation still need direct runtime UI checks. The local screenshot `clay-build-6-settings.png` is kept outside the source repository.

Both uploads succeeded on November 8, 2026 at 22:26:48.728 iOS and 22:26:54.657 macOS, America/Phoenix. Apple processing, Briggs assignment, and physical-phone build 6 installation remain pending. The verified build 5 two-way Mac–iPhone sync result below remains valid; Windows verification is postponed by the owner.

## Original artwork and folder-path fix — 0.1.0 (5)

Build 5 uses an exact crop of the original Clay symbol, the exact Bard gold maker's mark, and the shared PP Neue Montreal name treatment. The handwritten wordmark is absent. The Mac library and Settings show the symbol/name at the top and maker's mark at the bottom. The ten Mac icon sizes and iOS Dark icon have alpha and transparent corners; iOS Any has no alpha for distribution. Both Release archives passed, and all 52 captured native inputs remained unchanged during compilation. The 40 tracked inputs match source `d106286c96bba138055b8c9a6c1582fe8c623fe1`; the 12 generated inputs match their captured hashes.

The exact development-signed universal Mac build 5 archive was installed at `/Applications/Developer/Clay.app` after the owner quit normally and was later replaced by build 6; the prior app and all private data were preserved. Launch, library branding, Settings version 5, Light appearance, and returning to System were visually checked. The previously selected private-folder bookmark restored automatically, and Settings reported Storage “Clay” and “Shared folder updated.” A synthetic “Clay sync check” note saved successfully; its three immutable revisions and one matching Markdown export were verified in the selected personal iCloud folder. The owner subsequently confirmed build 5 installation on the physical iPhone, connection to the same iCloud Drive/Clay folder, and receipt of the Mac-created synthetic note. This establishes owner-confirmed Mac-to-phone delivery. The phone edit subsequently appeared in the Mac app with Saved status; the observer had not edited the note on Mac. That independently observed return edit completes the synthetic two-way sync check; the owner also confirmed the phone edit was saved and worked. The owner deferred the Windows receipt check. The iOS upload succeeded at 22:05:53.707 and macOS at 22:06:32.644 America/Phoenix on November 8, 2026. Both completed processing and show Testing in Briggs (1 Tester / 10 Builds). The saved App Store Connect name remains Clay by Briggs Kellogg, the build 5 beta description is saved, and no new invitation was sent. Physical-phone build 5 installation and folder connection are owner-confirmed.

Build 5 iOS ID: `adc93656-f7d1-4c0e-9e91-a1f09c8ef484`; macOS ID: `87ae7c2c-abe8-4bf4-846b-a27847c4329d`. Build 5 source `d106286c96bba138055b8c9a6c1582fe8c623fe1` is pushed to GitHub. Its 67-file local Proton mirror was hash-verified, and the Proton web manifest was observed at that commit. This cloud check inspected the manifest rather than every remote file byte. Subsequent delivery-documentation commits follow the same source-sync workflow; the source mirror manifest records the latest mirrored commit.

The path fix passed 19 targeted checks and the existing real transport and Store integration harnesses. It accepts equivalent ancestor-alias paths returned by coordination while still rejecting selected-leaf/internal symlinks, sibling escapes, and source destinations. The owner confirmed successful connection after the build 5 update, resolving the observed phone failure. The phone's exact original provider path was not captured.

## Private-library update — 0.1.0 (4)

The owner confirmed the same personal iCloud Drive account on iPhone, Mac, and Windows. The app now offers a selected private folder, separate from GitHub and the Proton source mirror. Ordinary Windows Markdown exports are derived reading copies; editing them does not update Clay.

| Check | Result |
| --- | --- |
| Core suite | All 38 XCTest methods passed, including 13 immutable-journal cases |
| Source privacy guard | Seven synthetic checks passed; detects known runtime paths/formats in Git index and tracked working files without logging contents |
| Actual Store + transport integration | Synthetic two-device checks passed: Unicode and metadata transfer; offline conflict convergence without duplicate growth; deletion across restart; export manifest/content; unavailable provider/outbox recovery; local journal failure blocks publication until retry |
| Folder-path regression for build 5 | All 19 synthetic checks passed. The unchanged validator reproduced three failures when a coordinator resolves an alias in an ancestor outside the selected folder; the fix accepts those equivalent paths. Checks also cover both `/tmp` and `/private/tmp` spellings, uncreated descendants, trailing slashes, sibling-prefix escapes, selected-folder/internal/dangling symlinks, and Git/Proton source-folder rejection. The existing transport and full Store integration harnesses passed again after the fix. This reproduces a path-validation defect. The owner subsequently confirmed successful phone connection in build 5; the exact original phone path was not captured. |
| Native builds | Both Mac and iOS Simulator Debug and both Release archives passed; both App Store Connect uploads succeeded |
| Folder transport | Synthetic bookmark restore/disconnect, coordinated immutable exchange, collision/symlink/source-folder rejection, and stable per-device exports passed |
| Mac installation and UI | Build 4 was installed at `/Applications/Developer/Clay.app` before the build 5 update; launch and Settings version 0.1.0 (4) were verified. The owner completed Connect while the app was in the foreground. Settings was then independently observed showing Storage “Clay” and “Shared folder updated.” The earlier disabled-picker observation was a limitation of background UI control. |
| Actual private cloud connection | Mac connection to the selected Clay folder is verified in the app. The owner later confirmed that the Mac-created synthetic note arrived on the connected build 5 phone. The return phone edit was independently observed in the Mac app with Saved status, completing the synthetic two-way check. Windows receipt is postponed; provider status alone is not remote-receipt evidence. |
| iPhone and Windows receipt | The owner confirmed build 4 installed and opened on the physical iPhone, selected iCloud Drive/Clay, and received the regular-folder/symbolic-link connection error. After updating to build 5, the owner confirmed successful connection and Mac-to-phone note receipt. The return phone edit was independently observed in the Mac app with Saved status. The synthetic two-way check passed; Windows verification was deferred by the owner. |
| TestFlight build 4 | Both uploads succeeded at 9:28 PM America/Phoenix on November 8, 2026, completed processing, and show Testing in Briggs: 1 Tester / 8 Builds. No new invitation was sent. Physical-phone installation and launch are now owner-confirmed; its private-folder connection failed as recorded above. |
| Source delivery | GitHub source `2cc916f3989956c75d73d08cdff42b7cd9979092`; 63 local Proton mirror files verified and the Proton web manifest observed at the same commit. The cloud manifest was inspected, not every remote file byte. This historical build 4 source snapshot is superseded by the build 5 source delivery above |

The production application does not print document bodies into release logs. Private journals, connection bookmarks, outboxes, and derived exports are excluded from source control and source mirroring. The immutable journal is durable before local projection writes, so recovery can rebuild a local Markdown copy after interruption. Local saving and cloud transfer status are separate.

## App-family finalization — 0.1.0 (3)

The code review confirmed Clay and Intersect share the six neutral color pairs and the Montreal/Neue York pairing; Bard uses the same typography and restrained neutral chrome. Clay retains its existing red artwork and amber/blue destination colors. Build 3 reduces the Mac sidebar signature and adds branded Settings. No persistence, library migration, cloud syncing, or editor behavior changes are included. Both native Debug builds and Release archives passed. The signed universal Mac archive passed strict code-signature verification; the iOS arm64 archive is prepared for App Store distribution re-signing. All 45 captured build inputs retained identical SHA-256 hashes before and after compilation. The 34 tracked inputs match source commit `f96326364c1907ef181c361f47a5189d9904e674`; the 11 generated icon inputs were unchanged.

Build 3 was installed at `/Applications/Developer/Clay.app`; the prior installation was preserved and the replacement signature verified. Visual checks confirmed the compact dark sidebar and branded Settings showing version 0.1.0 (3), legible Light appearance, and returning to System following the current OS dark appearance. Final selection is System. The unchanged appearance preference's Dark override and persistence checks are documented under build 2 below. Build 3's iOS Settings sheet has compiled but has not received a new runtime interaction check; at that point, physical-phone confirmation applied only to build 1. Build 4 was subsequently owner-confirmed as recorded above.

App Store Connect saved the requested **Clay by Briggs Kellogg** name on the existing multiplatform record. Both iOS and macOS build 3 uploads succeeded at **8:41 PM America/Phoenix on November 8, 2026**. Both completed Apple processing and are assigned to the internal **Briggs** group, with **Testing** status and 90-day expiry. The group shows **1 Tester / 6 Builds**; no duplicate invitation was sent. Physical-iPhone installation of build 3 has not yet been confirmed.

## Appearance update — 0.1.0 (2)

The update adds a persistent System/Light/Dark setting in Mac Settings and the iPhone library's gear sheet. The choice is local to each device.

| Check | Result |
| --- | --- |
| Source validation, both Debug builds, both Release archive builds | Passed |
| Mac installation | Build 2 installed at `/Applications/Developer/Clay.app`; signature verified |
| Mac default and switching | Settings defaulted to System; Light and Dark switching passed |
| Mac return to System | Dark → System restored the OS light appearance |
| Mac preference persistence | Saved Dark survived quit/relaunch; dark main library confirmed. Final preference restored to System. |
| iOS simulator System appearance | New Settings gear observed; System followed a live simulator OS change to dark |
| iOS simulator manual overrides | Visually passed: Dark with a light OS and Light with a dark OS, set through temporary UserDefaults launch arguments. Arguments were cleared afterward; System and the simulator's original light appearance were restored. |
| Live iOS Settings sheet selection/reset | Pending: UI automation coordinate control failed, so the live sheet interaction was not tested |
| TestFlight delivery | Both iOS and macOS build 2 uploads succeeded at 5:36 PM America/Phoenix on 2026-11-08; both completed Apple processing and were assigned to the internal Briggs group. Both show Testing; the group shows 1 Tester / 4 Builds. No duplicate invitation was sent. |
| Physical iPhone build 2 | Not verified; owner's prior installation/launch confirmation applies to build 1 |

## Source and package checks

| Check | Result |
| --- | --- |
| Xcode project generation | Passed; two native application targets with shared code and local ClayCore package |
| OpenStep project syntax and object-reference graph | Passed with `scripts/validate_source.py` |
| Target membership | Passed; each target contains all shared files, its own platform files, and exactly one app entry point |
| Font and resource references | Passed; required fonts, artwork, asset catalogs and privacy manifest are present and assigned to both targets |
| Info plists, entitlements, privacy manifest | Parsed successfully as property lists |
| Shared schemes and workspace metadata | Parsed successfully as XML and references resolve |
| Shell/Python scripts | Syntax checks passed; executable bits are set on shell launchers |
| Non-Mac preflight | Correctly refused to build with a clear requirement for macOS and full Xcode |
| Swift source review | Reviewed store API integration, platform availability, import/export handling, background/quit saves, and exact content preservation |

These checks validate packaging and source structure. Native compilation, signing, and runtime results are recorded separately below.

## Automated Swift tests — passed

All **25 XCTest methods passed** on the Mac. Their coverage includes:

- Exact metadata/body round trips, Unicode, CRLF, leading/trailing whitespace, and reference-date precision.
- Rejection of invalid UTF-8, corrupt metadata, nonfinite dates and unsupported format versions.
- New identities for imported copies and ordinary Markdown exports without the native header.
- Reopen behavior, section changes retaining identity, and a single active file per document.
- Preservation of the previous copy, including aborting a replacement when backup fails.
- Saving the last in-memory edit before Trash and blocking late queued saves from recreating it.
- Corrupt-file warnings without hiding good files or overwriting damaged bytes.
- Mismatched identity/filename rejection, invalid Trash locations and symbolic-link refusal.

To rerun on the build Mac:

```bash
xcrun swift test
```

The build and archive scripts run this gate automatically. A failing test stops those scripts. Core XCTest coverage does not replace testing the app's editor, store lifecycle, or platform UI.

## Initial release — 0.1.0 (1) results

| Check | Current result |
| --- | --- |
| `swift test` | Passed: 25 tests |
| macOS Debug and Release compilation | Passed |
| iOS simulator Debug compilation | Passed |
| iOS device Release compilation | Passed; compilation does not establish a phone runtime result |
| App icon generation/asset compilation | Passed after correcting RGB row-stride handling; original artwork unchanged |
| Mac archive and distribution package | Signed archive valid; exported `.pkg` verified |
| iOS archive and distribution package | Unsigned archive exported with `app-store-connect` and explicit team ID; resulting signed `.ipa` verified, without registered development devices |
| Initial Mac installation | Build 1 installed at `/Applications/Developer/Clay.app`, signature verified, and reopened successfully; later updates are recorded above |
| Mac UI smoke check | Passed: empty library, create/edit Unicode title and text, move Scratchpad to Pieces and back, quit/reopen with complete text and Saved status; temporary verification document moved to recoverable Trash, leaving the active library empty |
| iOS simulator launch/UI smoke | Passed on iPhone 17 Pro simulator, iOS 26.2: boot, install, and launch; screenshot showed healthy empty Scratchpads, New scratchpad, import/+ controls, and Scratchpads/Pieces tabs |
| Physical iPhone installation and launch | Build 1 owner-confirmed on November 8, 2026: “Installed and opened” after following the TestFlight installation instructions |
| iOS editing/persistence and accessibility inspection | Pending |
| App Store Connect record | Created: [Clay — Scratchpads & Pieces](https://appstoreconnect.apple.com/apps/6832381528/distribution), app ID `6832381528`, bundle `com.briggskellogg.clay`, iOS/macOS |
| TestFlight upload | Both iOS and macOS 0.1.0 (1) uploaded successfully at 5:09 PM America/Phoenix on 2026-11-08 |
| TestFlight processing and internal distribution | Both builds processed with a 90-day expiry and assigned to internal group Briggs using manual distribution; verified November 8 snapshot showed 1 Tester / 2 Builds |
| TestFlight invitation | App Store Connect showed `briggs@kellogg.co` as Invited on November 8, 2026; owner subsequently confirmed physical-iPhone installation/launch. App Store Connect status was not refreshed after that report. |
| Initial beta information | Feedback email and original local-only description saved for build 1; build 5’s saved description explains branding, optional private sync, and Windows reading copies |
| External beta review and public App Store release | Neither requested nor performed |

## Native acceptance pass

The completed Mac smoke check used throwaway writing. Complete the pending checks on the Mac and an iPhone before relying on this first beta; a passing build or export does not establish their runtime behavior.

| Scenario | Expected result | Status |
| --- | --- | --- |
| Fresh install | Empty library with useful creation controls; no example writing inserted | Passed on Mac and iOS simulator |
| Install and open through TestFlight on a physical iPhone | App installs and launches | Builds 1, 4, and 5 owner-confirmed November 8, 2026 |
| Create and edit Unicode writing | Title and full body remain intact | Passed on Mac |
| Create immediately after launch | Initial loading does not replace the newly created document or typed text | Pending timing/race check |
| Edit, quit immediately, reopen on Mac | Last edit persists; quit waits for saving | Basic quit/reopen passed; immediate-quit stress check pending |
| Type and immediately background/reopen iPhone | Last edit persists; save status is accurate | Pending |
| Rapid foreground/background cycles | Save work is not dropped; a finite background lease ends when finished | Pending |
| Edit while an older save is in flight | Older completion never marks a newer edit as saved | Pending app lifecycle check |
| Save failure | Writing stays available; visible error and Retry; Mac quit can be cancelled | Pending UI check |
| Move Scratchpad → Piece → Scratchpad | One document remains, with unchanged text and identity | Passed on Mac |
| Pin/unpin, search and collections | Correct ordering/filtering with no content changes | Pending |
| Import valid text alongside a bad file | Good file imports; failed file produces a useful message; source files remain unchanged | Pending |
| Import then immediately quit | Mac waits for imports and pending saves | Pending |
| Export then cancel | Cancelling does not show a failure alert | Pending |
| Export and reopen in another text editor | Ordinary UTF-8 Markdown, with title handling described in README | Pending UI check |
| Trash immediately after typing | Latest body is preserved in Trash; older saves do not resurrect it | Ordinary Mac Trash passed; immediate-after-typing UI check pending; core regression passed |
| Recover on Mac | Reimporting a previous/trashed file creates an independent recovered copy | Pending |
| Phone editor with keyboard and larger text | Writing remains reachable, controls have usable targets, Done dismisses the keyboard | Pending |
| Focus mode and document switching on Mac | Text/selection stays stable; navigation can be restored | Pending |
| Appearance preference | System follows OS; manual choices persist and can return to System | Build 2 Mac checks passed; iOS System and opposing manual overrides passed in simulator. Live iOS sheet selection/reset and persistence through that UI remain pending. |
| VoiceOver and complete light/dark contrast inspection | Labels remain legible and destinations understandable without relying only on color | Pending |
| First signed device build | Native fonts, app icon, file pickers and sandbox storage behave correctly | Physical-phone installation/launch and selected-folder connection owner-confirmed in build 5; complete device UI checks remain pending; signed IPA verified |

Builds 4 and later add optional private-folder synchronization. Build 5 Mac-to-phone synthetic-note receipt is owner-confirmed, and the return phone edit was independently observed in the Mac app with Saved status. The synthetic two-way check passed. Windows reading-export reception remains postponed. Local publication, signed builds, and TestFlight availability alone do not establish remote receipt.
