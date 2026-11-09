#if os(iOS)
import ClayCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ClayIOSLibraryView: View {
    @ObservedObject var store: ClayStore
    @State private var path: [UUID] = []
    @State private var isImporting = false
    @State private var isShowingSettings = false
    @State private var pendingTrash: WritingDocument?

    var body: some View {
        NavigationStack(path: $path) {
            library
                .navigationTitle(store.selectedSection.title)
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(ClayTheme.paper, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .foregroundStyle(ClayTheme.secondary)
                        .accessibilityLabel("Settings")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            isImporting = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .foregroundStyle(ClayTheme.secondary)
                        .accessibilityLabel("Import writing")
                        .keyboardShortcut("o", modifiers: .command)

                        Button(action: newScratchpad) {
                            Label("New", systemImage: "plus")
                                .font(ClayTheme.uiFont(size: 16, weight: .bold))
                        }
                        .foregroundStyle(ClayTheme.blue)
                        .accessibilityLabel("New scratchpad")
                        .keyboardShortcut("n", modifiers: .command)
                    }
                }
                .searchable(
                    text: $store.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: store.selectedSection == .scratchpads
                        ? "Find a scratchpad" : "Find a piece"
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    sectionPicker
                }
                .navigationDestination(for: UUID.self) { documentID in
                    DocumentEditor(store: store, documentID: documentID)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .background(ClayTheme.paper)
        .sheet(isPresented: $isShowingSettings) {
            ClaySettingsView()
                .clayAppearance()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: Self.importTypes,
            allowsMultipleSelection: true,
            onCompletion: handleImport
        )
        .onOpenURL { url in
            guard url.isFileURL else { return }
            importWriting(from: [url])
        }
        .onChange(of: path) { _, newPath in
            store.selectedDocumentID = newPath.last
            reconcileNavigation()
        }
        .onChange(of: store.documents) { _, _ in
            reconcileNavigation()
        }
        .confirmationDialog(
            "Move writing to Trash?",
            isPresented: trashIsPresented,
            titleVisibility: .visible,
            presenting: pendingTrash
        ) { document in
            Button("Move to Trash", role: .destructive) {
                store.trash(id: document.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { document in
            Text(document.displayTitle)
        }
        .alert("Clay", isPresented: errorIsPresented) {
            if store.saveStatus == "Save failed" {
                Button("Retry save") {
                    Task { await store.retrySave() }
                }
            }
            Button("Dismiss", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var library: some View {
        List {
            ForEach(store.visibleDocuments) { document in
                NavigationLink(value: document.id) {
                    ClayIOSDocumentRow(document: document)
                }
                .listRowBackground(ClayTheme.paper)
                .listRowSeparatorTint(ClayTheme.rule)
                .listRowInsets(
                    EdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingTrash = document
                    } label: {
                        Label("Trash", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: 720)
        .overlay {
            if store.visibleDocuments.isEmpty {
                emptyLibrary
                    .frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClayTheme.paper)
    }

    @ViewBuilder
    private var emptyLibrary: some View {
        if !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: store.query)
        } else {
            ContentUnavailableView {
                Label {
                    Text(store.selectedSection == .scratchpads
                         ? "No scratchpads yet" : "No pieces yet")
                        .font(ClayTheme.uiFont(size: 22, weight: .bold))
                        .foregroundStyle(ClayTheme.ink)
                } icon: {
                    SectionSymbol(section: store.selectedSection, size: 36)
                }
            } description: {
                Text(store.selectedSection == .scratchpads
                     ? "A place for thoughts that are still taking shape."
                     : "Move a finished scratchpad here from its editor.")
                    .font(ClayTheme.uiFont(size: 16, weight: .regular))
                    .foregroundStyle(ClayTheme.secondary)
            } actions: {
                if store.selectedSection == .scratchpads {
                    Button("New scratchpad", action: newScratchpad)
                        .buttonStyle(.borderedProminent)
                        .tint(ClayTheme.blue)
                }
            }
        }
    }

    private var sectionPicker: some View {
        ClayIOSSectionPicker(
            selection: store.selectedSection,
            select: selectSection
        )
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(ClayTheme.sidebar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ClayTheme.rule)
                .frame(height: 0.5)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented { store.errorMessage = nil }
            }
        )
    }

    private var trashIsPresented: Binding<Bool> {
        Binding(
            get: { pendingTrash != nil },
            set: { isPresented in
                if !isPresented { pendingTrash = nil }
            }
        )
    }

    private static var importTypes: [UTType] {
        [.plainText, MarkdownFile.contentType]
    }

    private func selectSection(_ section: WritingSection) {
        store.selectSection(section)
    }

    private func newScratchpad() {
        store.selectSection(.scratchpads)
        store.query = ""
        store.collectionFilter = nil
        let id = store.createDocument(section: .scratchpads)
        path = [id]
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            importWriting(from: urls)
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            store.errorMessage = "Couldn’t import writing. \(error.localizedDescription)"
        }
    }

    private func importWriting(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        path = []
        store.query = ""
        store.collectionFilter = nil
        Task {
            await store.importDocuments(from: urls)
            if path.isEmpty {
                store.selectedDocumentID = nil
            }
        }
    }

    private func reconcileNavigation() {
        guard let id = path.last else { return }
        guard let document = store.document(id: id) else {
            path = []
            store.selectedDocumentID = nil
            return
        }

        // The root title supplies the native Back label, including after a move.
        if store.selectedSection != document.section {
            store.selectedSection = document.section
        }
    }
}

@MainActor
private struct ClayIOSDocumentRow: View {
    let document: WritingDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(document.displayTitle)
                    .font(ClayTheme.uiFont(size: 18, weight: .bold))
                    .foregroundStyle(ClayTheme.ink)
                    .lineLimit(2)
                if document.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ClayTheme.amber)
                        .accessibilityLabel("Pinned")
                }
            }

            Text(preview)
                .font(ClayTheme.bodyFont(size: 18))
                .foregroundStyle(ClayTheme.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                if !document.collection.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(document.collection)
                        .lineLimit(1)
                    Text("·")
                        .accessibilityHidden(true)
                }
                Text("\(document.wordCount) \(document.wordCount == 1 ? "word" : "words")")
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(ClayTheme.uiFont(size: 12, weight: .regular))
            .foregroundStyle(ClayTheme.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        let text = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "No text yet" }
        let firstParagraph = text.components(separatedBy: "\n\n").first ?? text
        return String(firstParagraph.prefix(200))
    }
}

@MainActor
private struct ClayIOSSectionPicker: View {
    let selection: WritingSection
    let select: (WritingSection) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            ForEach(WritingSection.allCases) { section in
                Button {
                    select(section)
                } label: {
                    label(for: section)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .background(
                            selection == section ? ClayTheme.selection : .clear,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Writing library")
    }

    private func label(for section: WritingSection) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 4))

        return layout {
            SectionSymbol(section: section, size: 23)
                .accessibilityHidden(true)
            Text(section.title)
                .font(ClayTheme.uiFont(
                    size: 13,
                    weight: selection == section ? .bold : .regular
                ))
                .foregroundStyle(selection == section ? ClayTheme.ink : ClayTheme.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
#endif
