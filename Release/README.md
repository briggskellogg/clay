# Clay release scope

Build 3 finalizes the Mac sidebar signature and shared Settings branding: the Clay glyph, Montreal name, “by Briggs Kellogg,” and version/build information. It preserves the existing palette, typefaces, Scratchpads/Pieces model, and saved System/Light/Dark behavior. The saved App Store Connect/TestFlight display name is **Clay by Briggs Kellogg**; the native installed display name and product artifact remain **Clay** and `Clay.app`.

Keep the existing app identity: App Store Connect app `6832381528`, bundle `com.briggskellogg.clay`, and the internal Briggs testing group. The destination manifest records these identities and the release build; it is not evidence that a new build has passed validation, uploaded, finished processing, or reached a tester. Record those results in `README.md`, `TEST_REPORT.md`, and `DISTRIBUTION.md` after verification.

The user's November 8, 2026 clarification authorizes the established source workflow using GitHub and Proton Drive `[projects]/clay`. Follow `SYNC.md` to commit/push the intended source and conservatively mirror tracked files. The public repository and source mirror must not contain personal writing, app library data, credentials, signing-local configuration, generated builds, or account-specific filesystem paths. The developer team ID in the destination manifest is a non-secret release identifier; signing credentials remain in the local Apple tooling.

This release does not implement cross-device writing sync or a backup service. Libraries and preferences remain local to each installation. iCloud/CloudKit, personal-data storage in Proton Drive, Windows backup destinations, and automated backup schedules are explicitly unconfigured in the manifest. Do not treat a broader proposed cloud architecture as completed work or as authorization to populate those destinations.

GitHub's existing public visibility is recorded without changing it. The Proton project folder is fixed at `[projects]/clay`; the sync script resolves its existing account root locally. Verify Proton's completed cloud upload separately from the script's local hash checks. No new scheduler is created by this workflow.
