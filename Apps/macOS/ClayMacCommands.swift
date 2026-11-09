import ClayCore
import SwiftUI

@MainActor
struct ClayMacCommands: Commands {
    @ObservedObject var store: ClayStore
    @ObservedObject var actions: ClayMacActions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Scratchpad") {
                openWindow(id: "library")
                actions.newScratchpad(in: store)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(actions.isTerminating)

            Button("Import Markdown…") {
                openWindow(id: "library")
                actions.isImportPresented = true
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(actions.isTerminating)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Now") {
                Task { await store.flush() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(actions.isTerminating)

            Button("Export Markdown…") {
                guard let id = store.selectedDocumentID else { return }
                openWindow(id: "library")
                actions.export(id: id, from: store)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(store.selectedDocument == nil || actions.isTerminating)
        }

        CommandMenu("Writing") {
            Button("Show Library") {
                openWindow(id: "library")
                store.isFocusMode = false
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(actions.isTerminating)

            Button("Search \(store.selectedSection.title)") {
                openWindow(id: "library")
                actions.search(in: store)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(actions.isTerminating)

            Toggle("Focus Mode", isOn: $store.isFocusMode)
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled((store.selectedDocument == nil && !store.isFocusMode) || actions.isTerminating)

            Divider()

            Button(store.selectedDocument?.pinned == true ? "Unpin Document" : "Pin Document") {
                guard let id = store.selectedDocumentID else { return }
                store.togglePin(id: id)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(store.selectedDocument == nil || actions.isTerminating)

            Button(store.selectedDocument?.section == .pieces ? "Move to Scratchpads" : "Move to Pieces") {
                guard let document = store.selectedDocument else { return }
                store.move(id: document.id, to: document.section == .pieces ? .scratchpads : .pieces)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(store.selectedDocument == nil || actions.isTerminating)

            Button("Move to Trash", role: .destructive) {
                guard let id = store.selectedDocumentID else { return }
                actions.trash(id: id, in: store)
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(store.selectedDocument == nil || actions.isTerminating)

            Divider()

            Button("Show Library in Finder") {
                actions.showLibraryFolder(in: store)
            }
            .disabled(actions.isTerminating)

            Button("Show Deleted Documents in Finder") {
                actions.showLibraryFolder(in: store, deletedDocuments: true)
            }
            .disabled(actions.isTerminating)
        }
    }
}
