# Clay 0.1 validation

Updated 2026-11-08 after native testing on the owner's Mac. This report distinguishes completed source, build, signing, and Mac smoke checks from the remaining acceptance work.

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

## Native build and distribution results

| Check | Current result |
| --- | --- |
| `swift test` | Passed: 25 tests |
| macOS Debug and Release compilation | Passed |
| iOS simulator Debug compilation | Passed |
| iOS device Release compilation | Passed; compilation does not establish a phone runtime result |
| App icon generation/asset compilation | Passed after correcting RGB row-stride handling; original artwork unchanged |
| Mac archive and distribution package | Signed archive valid; exported `.pkg` verified |
| iOS archive and distribution package | Unsigned archive exported with `app-store-connect` and explicit team ID; resulting signed `.ipa` verified, without registered development devices |
| Mac installation | Installed at `/Applications/Developer/Clay.app`, signature verified, and reopened successfully |
| Mac UI smoke check | Passed: empty library, create/edit Unicode title and text, move Scratchpad to Pieces and back, quit/reopen with complete text and Saved status; temporary verification document moved to recoverable Trash, leaving the active library empty |
| iPhone/simulator runtime and accessibility inspection | Pending |
| TestFlight upload | Owner approved. iOS attempt failed because the App Store Connect app record for `com.briggskellogg.clay` is missing; Mac upload not attempted because it requires the same record. Browser sign-in is pending before creating the record. No build accepted or uploaded. |
| TestFlight processing, review and invitation | Pending; no tester availability or invitation confirmed |

## Native acceptance pass

The completed Mac smoke check used throwaway writing. Complete the pending checks on the Mac and an iPhone before relying on this first beta; a passing build or export does not establish their runtime behavior.

| Scenario | Expected result | Status |
| --- | --- | --- |
| Fresh install | Empty library with useful creation controls; no example writing inserted | Passed on Mac |
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
| Light/dark appearance and VoiceOver | Labels remain legible and destinations understandable without relying only on color | Pending |
| First signed device build | Native fonts, app icon, file pickers and sandbox storage behave correctly | Runtime pending; signed IPA verified |

There is no cross-device sync in 0.1, so editing on the Mac is not expected to change the phone's library. No network-service test is required for this implementation.
