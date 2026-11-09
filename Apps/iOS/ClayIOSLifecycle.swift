#if os(iOS)
import Combine
import Foundation
import SwiftUI
import UIKit

/// Gives the final local save a finite execution lease during suspension.
@MainActor
final class ClayIOSLifecycle: ObservableObject {
    private var handledInactiveTransition = false
    private var flushTask: Task<Void, Never>?
    private var flushAgain = false
    private var lease: UIBackgroundTaskIdentifier = .invalid
    private var leaseToken: UUID?

    func scenePhaseChanged(to phase: ScenePhase, store: ClayStore) {
        switch phase {
        case .active:
            handledInactiveTransition = false
            store.setSyncActive(true)
        case .inactive, .background:
            store.setSyncActive(false)
            // The same departure from the foreground normally sends both phases.
            guard !handledInactiveTransition else { return }
            handledInactiveTransition = true
            requestFlush(store: store)
        @unknown default:
            break
        }
    }

    private func requestFlush(store: ClayStore) {
        beginLeaseIfNeeded()
        if flushTask != nil {
            // A later foreground/background cycle may contain fresh edits.
            flushAgain = true
            return
        }

        flushTask = Task { @MainActor [self] in
            repeat {
                flushAgain = false
                await store.flush()
            } while flushAgain
            endLease()
            flushTask = nil
        }
    }

    private func beginLeaseIfNeeded() {
        guard lease == .invalid else { return }
        let token = UUID()
        leaseToken = token
        lease = UIApplication.shared.beginBackgroundTask(withName: "Save Clay writing") { [weak self] in
            Task { @MainActor [weak self] in
                // Expiration ends only the lease. Repository writes are not cancelled.
                self?.endLease(matching: token)
            }
        }
        if lease == .invalid { leaseToken = nil }
    }

    private func endLease(matching token: UUID? = nil) {
        if let token, token != leaseToken { return }
        let identifier = lease
        lease = .invalid
        leaseToken = nil
        if identifier != .invalid {
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }
}
#endif
