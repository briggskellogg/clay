# Clay working rules

Preserve Clay's Scratchpads/Pieces design and Bard visual identity. Maintain the existing local persistence and recovery guarantees. Read README.md, TEST_REPORT.md, DISTRIBUTION.md, and SYNC.md for current scope and delivery evidence.

The user requires the corresponding local source folder, GitHub repository `https://github.com/briggskellogg/clay`, and Proton Drive `[projects]/clay` to stay synchronized after completed Clay changes. Follow SYNC.md: fetch/reconcile, validate, commit/push without force, run the conservative Proton mirror, and verify upload state. Record any incomplete destination accurately. This is an end-of-work procedure, not a claim that a background service exists.

Desktop install location: `/Applications/Developer/Clay.app`. Preserve app data and existing installations when updating. Phone delivery is through the requested TestFlight beta; never label a simulator or an exported IPA as installed on the user's phone.

Keep signing-local configuration, credentials, private keys, personal writing, build output and Git internals out of the Proton source mirror. Personal writing remains local to each device in version 0.1; source sync does not implement cross-device writing sync.
