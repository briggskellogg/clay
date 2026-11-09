import AppKit

/// AppKit gives us time to finish pending writes before the process exits.
/// A failed save offers Retry or Cancel Quit; there is deliberately no discard path.
@MainActor
final class ClayMacAppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: ClayStore?
    private weak var actions: ClayMacActions?
    private var terminationTask: Task<Void, Never>?

    func configure(store: ClayStore, actions: ClayMacActions) {
        self.store = store
        self.actions = actions
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else { return .terminateLater }
        guard let store else { return .terminateNow }

        // Prevent edits and menu mutations while the final save is being checked.
        actions?.isTerminating = true
        terminationTask = Task { @MainActor [weak self] in
            guard let self else {
                sender.reply(toApplicationShouldTerminate: false)
                return
            }

            await self.actions?.finishPendingImports()
            await store.flush()
            while store.saveStatus != "Saved" {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Your latest changes aren’t saved yet."
                alert.informativeText = store.errorMessage
                    ?? "Clay couldn’t finish saving your writing. Retry the save, or cancel quitting to keep your changes open."
                alert.addButton(withTitle: "Retry Save")
                alert.addButton(withTitle: "Cancel Quit")
                alert.buttons.last?.keyEquivalent = "\u{1b}"

                if alert.runModal() == .alertFirstButtonReturn {
                    await store.retrySave()
                } else {
                    self.actions?.isTerminating = false
                    self.terminationTask = nil
                    sender.reply(toApplicationShouldTerminate: false)
                    return
                }
            }

            self.terminationTask = nil
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
