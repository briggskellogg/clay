# Clay release scope

## Build 5 — current candidate

Build 5 uses an exact pixel crop of the original Clay symbol without its lettering and the original 416 × 512 gold maker asset, preserved byte for byte. The library and Settings pair the symbol with Clay in the shared interface font at the top and place the maker's mark in the lower corner. The Mac icon is transparent; iOS provides a transparent Dark appearance and an opaque Any appearance fallback. See ASSETS.md and DESIGN.md for the asset provenance and layout.

The candidate also fixes private-folder validation for file-provider paths containing an ancestor alias, following the owner's failed build 4 phone connection. All 19 focused path cases and actual transport/Store regression checks passed. Both native Release archives passed; uploads are pending, and source commit, build IDs, TestFlight availability, Mac installation/bookmark restoration, and physical-phone build 5 installation/connection remain pending. Keep `verified_release` at build 4 until delivery evidence supports advancing it; `pending_release` records build 5 separately.

## Build 4 — delivered beta, Mac private connection verified

The owner explicitly requested that private writing stay out of GitHub and remain available across phone, Mac, and PC, then confirmed the same personal iCloud Drive account on all three. Build 4 implements a dedicated, user-selected personal iCloud Drive/Clay folder. Its private `ClaySync/Records` contains immutable synchronization history; `ClaySync/Exports/<deviceID>` contains readable Markdown snapshots for Windows. The local `Clay/SyncJournal` preserves offline changes, conflicting edits become copies, and tombstones prevent silent resurrection of deleted originals.

The 38-test core suite, synthetic Store/transport integration, privacy checks, both Debug builds, and Release archives passed. Both build 4 uploads completed at 9:28 PM America/Phoenix on November 8, 2026 and show Testing in Briggs (1 Tester / 8 Builds). The development-signed Mac app is installed, and launch plus Settings version 4 were verified. Foreground user interaction connected personal iCloud Drive/Clay; Settings showed Storage: Clay and Shared folder updated. The private folder contains `ClaySync/format.json`, `Records`, and `Exports`, with zero records, so no private writing was transferred. Background automation had caused the earlier disabled Mac Connect button.

The owner confirmed physical-phone build 4 installation, but its regular-folder connection failed. Phone connection, Windows reception, and an end-to-end synchronization check remain pending. Do not call them verified from compilation, a local folder write, or an upload alone. Exports are derived reading copies; editing them does not import changes into Clay. No Windows native application or PC backup jobs are included.

## Existing verified identity and delivery

App Store Connect/TestFlight is named **Clay by Briggs Kellogg**. Keep app `6832381528`, bundle `com.briggskellogg.clay`, and the internal Briggs group. The installed product remains **Clay** / `Clay.app`. Build 3 finalized the compact Mac sidebar and branded Settings while preserving the existing palette, typography, Scratchpads/Pieces model, and System/Light/Dark appearance setting. Build 4 remains the latest verified Testing release on both platforms; build 5 is the delivery candidate. Private-data receipt and cross-device checks are separate from source and app delivery.

`project-destinations.json` separates stable identities, delivered builds, and pending private-data verification. Build 4 source `2cc916f3989956c75d73d08cdff42b7cd9979092` is pushed. Its 63-file local Proton mirror was verified, and the Proton web manifest was observed at that commit; the cloud check did not compare every remote file byte. Build 5 source and updated delivery documentation still await publication and mirroring. Keep subsequent README.md, TEST_REPORT.md, and DISTRIBUTION.md status changes evidence-based.

## Source and private-data boundary

GitHub and Proton Drive `[projects]/clay` contain tracked source and release documentation only. Follow SYNC.md to review/stage, check source privacy, commit/push, and conservatively mirror those files. Private writing, document metadata, sync records, readable exports, app libraries/recovery data, credentials, signing-local configuration, and generated builds must not enter either source destination. Keep runtime storage outside repositories and `[projects]`.

Run `python3 scripts/check-source-privacy.py --staged` before committing/pushing. Its known-format checks support the boundary but cannot classify arbitrary private prose. Keep review and the physical separation of data from source. The public repository's existing visibility remains unchanged; its non-secret developer team identifier is release metadata, while signing credentials stay in local Apple tooling.

The broader PC archive and Proton personal-data backup pipeline is separate. This release creates no backup jobs or schedules and has not inspected any existing external pipeline. Exact approved private backup destinations remain unknown in this release manifest. Do not substitute the source folder for a private backup destination or collect work-Mac folders. Verify Proton source upload completion separately from local mirror hashes.
