# Clay release scope

## Build 4 — implementation pending validation and delivery

The owner explicitly requested that private writing stay out of GitHub and remain available across phone, Mac, and PC, then confirmed the same personal iCloud Drive account on all three. Build 4 implements a dedicated, user-selected personal iCloud Drive/Clay folder. Its private `ClaySync/Records` contains immutable synchronization history; `ClaySync/Exports/<deviceID>` contains readable Markdown snapshots for Windows. The local `Clay/SyncJournal` preserves offline changes, conflicting edits become copies, and tombstones prevent silent resurrection of deleted originals.

The actual cloud connection, physical-phone update, Windows reception, and end-to-end synchronization check are pending. Do not call them verified from compilation, a local folder write, or an upload alone. Exports are derived reading copies; editing them does not import changes into Clay. No Windows native application or PC backup jobs are included.

## Existing verified identity and delivery

App Store Connect/TestFlight is named **Clay by Briggs Kellogg**. Keep app `6832381528`, bundle `com.briggskellogg.clay`, and the internal Briggs group. The installed product remains **Clay** / `Clay.app`. Build 3 finalized the compact Mac sidebar and branded Settings while preserving the existing palette, typography, Scratchpads/Pieces model, and System/Light/Dark appearance setting. It is the latest verified Testing release on both platforms; build 4 awaits validation and delivery.

`project-destinations.json` separates stable identities, the last verified release, and pending work. The latest pushed delivery-documentation revision is `7b360a60c534dd8c975914f939783f17a89a1e04`; the build 4 working changes and their source mirror are pending. Record final results in README.md, TEST_REPORT.md, and DISTRIBUTION.md after observing them.

## Source and private-data boundary

GitHub and Proton Drive `[projects]/clay` contain tracked source and release documentation only. Follow SYNC.md to review/stage, check source privacy, commit/push, and conservatively mirror those files. Private writing, document metadata, sync records, readable exports, app libraries/recovery data, credentials, signing-local configuration, and generated builds must not enter either source destination. Keep runtime storage outside repositories and `[projects]`.

Run `python3 scripts/check-source-privacy.py --staged` before committing/pushing. Its known-format checks support the boundary but cannot classify arbitrary private prose. Keep review and the physical separation of data from source. The public repository's existing visibility remains unchanged; its non-secret developer team identifier is release metadata, while signing credentials stay in local Apple tooling.

The broader PC archive and Proton personal-data backup pipeline is separate. This release creates no backup jobs or schedules and has not inspected any existing external pipeline. Exact approved private backup destinations remain unknown in this release manifest. Do not substitute the source folder for a private backup destination or collect work-Mac folders. Verify Proton source upload completion separately from local mirror hashes.
