# Clay 0.1 validation

Updated 2026-11-08 after native Mac and simulator testing and the owner's physical-iPhone installation/launch confirmation. This report distinguishes independently observed checks, owner-reported results, and remaining acceptance work.

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
| TestFlight delivery | Both iOS and macOS build 2 uploads succeeded at 5:36 PM America/Phoenix on 2026-11-08, with Apple package processing confirmed. TestFlight group assignment remains pending. |
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
| Initial Mac installation | Build 1 installed at `/Applications/Developer/Clay.app`, signature verified, and reopened successfully; subsequently replaced by build 2 as recorded above |
| Mac UI smoke check | Passed: empty library, create/edit Unicode title and text, move Scratchpad to Pieces and back, quit/reopen with complete text and Saved status; temporary verification document moved to recoverable Trash, leaving the active library empty |
| iOS simulator launch/UI smoke | Passed on iPhone 17 Pro simulator, iOS 26.2: boot, install, and launch; screenshot showed healthy empty Scratchpads, New scratchpad, import/+ controls, and Scratchpads/Pieces tabs |
| Physical iPhone installation and launch | Build 1 owner-confirmed on November 8, 2026: “Installed and opened” after following the TestFlight installation instructions |
| iOS editing/persistence and accessibility inspection | Pending |
| App Store Connect record | Created: [Clay — Scratchpads & Pieces](https://appstoreconnect.apple.com/apps/6832381528/distribution), app ID `6832381528`, bundle `com.briggskellogg.clay`, iOS/macOS |
| TestFlight upload | Both iOS and macOS 0.1.0 (1) uploaded successfully at 5:09 PM America/Phoenix on 2026-11-08 |
| TestFlight processing and internal distribution | Both builds processed with a 90-day expiry and assigned to internal group Briggs using manual distribution; verified November 8 snapshot showed 1 Tester / 2 Builds |
| TestFlight invitation | App Store Connect showed `briggs@kellogg.co` as Invited on November 8, 2026; owner subsequently confirmed physical-iPhone installation/launch. App Store Connect status was not refreshed after that report. |
| Beta information | Feedback email and description saved; description identifies local-only writing libraries |
| External beta review and public App Store release | Neither requested nor performed |

## Native acceptance pass

The completed Mac smoke check used throwaway writing. Complete the pending checks on the Mac and an iPhone before relying on this first beta; a passing build or export does not establish their runtime behavior.

| Scenario | Expected result | Status |
| --- | --- | --- |
| Fresh install | Empty library with useful creation controls; no example writing inserted | Passed on Mac and iOS simulator |
| Install and open through TestFlight on a physical iPhone | App installs and launches | Build 1 owner-confirmed November 8, 2026; build 2 pending |
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
| First signed device build | Native fonts, app icon, file pickers and sandbox storage behave correctly | Runtime pending; signed IPA verified |

There is no cross-device sync in 0.1, so editing on the Mac is not expected to change the phone's library. No network-service test is required for this implementation.
