import ClayCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ClayMacLibraryView: View {
    @ObservedObject var store: ClayStore
    @ObservedObject var actions: ClayMacActions
    @FocusState private var searchHasFocus: Bool

    var body: some View {
        HSplitView {
            if !store.isFocusMode {
                sidebar
                    .frame(minWidth: 180, idealWidth: 205, maxWidth: 260)
                documentList
                    .frame(minWidth: 235, idealWidth: 285, maxWidth: 390)
            }
            // Keep the editor in the same view position when panels are hidden,
            // preserving its reading mode and native editing state.
            editor
                .frame(minWidth: 420, maxWidth: .infinity)
        }
        .background(ClayTheme.paper)
        .foregroundStyle(ClayTheme.ink)
        .font(ClayTheme.uiFont(size: 14, weight: .regular))
        .navigationTitle("Clay")
        .toolbar { windowToolbar }
        .disabled(actions.isTerminating)
        .overlay {
            if actions.isTerminating {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Saving your writing…")
                        .font(ClayTheme.uiFont(size: 13, weight: .medium))
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .onChange(of: actions.searchRequest) { _, _ in
            searchHasFocus = true
        }
        .onChange(of: store.selectedDocumentID) { _, selection in
            if selection == nil { store.isFocusMode = false }
        }
        .fileImporter(
            isPresented: $actions.isImportPresented,
            allowedContentTypes: [MarkdownFile.contentType, .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                actions.importDocuments(from: urls, into: store)
            case .failure(let error):
                actions.reportFileError(error, in: store)
            }
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            actions.importDocuments(from: [url], into: store)
        }
        .fileExporter(
            isPresented: $actions.isExportPresented,
            document: actions.exportDocument,
            contentType: MarkdownFile.contentType,
            defaultFilename: actions.exportFilename
        ) { result in
            actions.exportDocument = nil
            if case .failure(let error) = result {
                actions.reportFileError(error, in: store)
            }
        }
        .alert("Clay needs your attention", isPresented: errorIsPresented) {
            if store.saveStatus == "Save failed" {
                Button("Retry Save") {
                    Task { await store.retrySave() }
                }
            }
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil && !actions.isTerminating },
            set: { if !$0 && !actions.isTerminating { store.errorMessage = nil } }
        )
    }

    @ToolbarContentBuilder
    private var windowToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                store.isFocusMode.toggle()
            } label: {
                Label(
                    store.isFocusMode ? "Show Library" : "Focus Mode",
                    systemImage: store.isFocusMode ? "sidebar.left" : "viewfinder"
                )
            }
            .help(store.isFocusMode ? "Show library (⌥⌘F)" : "Hide side panels (⌥⌘F)")
            .disabled(store.selectedDocument == nil && !store.isFocusMode)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                actions.newScratchpad(in: store)
            } label: {
                Label("New Scratchpad", systemImage: "square.and.pencil")
            }
            .help("New scratchpad (⌘N)")

            Button {
                actions.isImportPresented = true
            } label: {
                Label("Import Markdown", systemImage: "tray.and.arrow.down")
            }
            .help("Import Markdown or text files (⌘O)")

            Button {
                guard let id = store.selectedDocumentID else { return }
                actions.export(id: id, from: store)
            } label: {
                Label("Export Markdown", systemImage: "square.and.arrow.up")
            }
            .help("Export this document as Markdown (⇧⌘E)")
            .disabled(store.selectedDocument == nil)

            Button {
                guard let id = store.selectedDocumentID else { return }
                actions.trash(id: id, in: store)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .help("Move this document to Clay’s recovery folder (⌘⌫)")
            .disabled(store.selectedDocument == nil)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("ClayMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
                Text("Clay")
                    .font(ClayTheme.uiFont(size: 20, weight: .bold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 18)

            Text("LIBRARY")
                .font(ClayTheme.uiFont(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(ClayTheme.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(WritingSection.allCases) { section in
                    sectionButton(section)
                }
            }
            .padding(.horizontal, 10)

            if !store.collections.isEmpty {
                HStack {
                    Text("COLLECTIONS")
                        .font(ClayTheme.uiFont(size: 10, weight: .semibold))
                        .tracking(1.1)
                    Spacer()
                }
                .foregroundStyle(ClayTheme.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 29)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(store.collections, id: \.self) { collection in
                            collectionButton(collection)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 7) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12))
                Text("Stored on this Mac")
                    .font(ClayTheme.uiFont(size: 11, weight: .regular))
            }
            .foregroundStyle(ClayTheme.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 19)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ClayTheme.sidebar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library navigation")
    }

    private func sectionButton(_ section: WritingSection) -> some View {
        let isSelected = store.selectedSection == section && store.collectionFilter == nil
        let count = store.documents.filter { $0.section == section }.count
        return Button {
            store.selectSection(section)
        } label: {
            HStack(spacing: 10) {
                SectionSymbol(section: section, size: 21)
                    .frame(width: 24)
                Text(section.title)
                    .font(ClayTheme.uiFont(size: 14, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 4)
                Text(count.formatted())
                    .font(ClayTheme.uiFont(size: 11, weight: .regular))
                    .foregroundStyle(ClayTheme.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(isSelected ? ClayTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.title), \(count) documents")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func collectionButton(_ collection: String) -> some View {
        let isSelected = store.collectionFilter == collection
        return Button {
            store.collectionFilter = collection
            if !store.visibleDocuments.contains(where: { $0.id == store.selectedDocumentID }) {
                store.selectedDocumentID = store.visibleDocuments.first?.id
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ClayTheme.secondary)
                    .frame(width: 24)
                Text(collection)
                    .font(ClayTheme.uiFont(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(isSelected ? ClayTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(collection)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var documentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                if store.collectionFilter != nil {
                    Text(store.selectedSection.title)
                        .font(ClayTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(ClayTheme.secondary)
                }
                Text(store.collectionFilter ?? store.selectedSection.title)
                    .font(ClayTheme.uiFont(size: 24, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(documentCountLabel)
                    .font(ClayTheme.uiFont(size: 12, weight: .regular))
                    .foregroundStyle(ClayTheme.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 17)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ClayTheme.secondary)
                TextField("Search \(store.selectedSection.title.lowercased())", text: $store.query)
                    .textFieldStyle(.plain)
                    .focused($searchHasFocus)
                    .font(ClayTheme.uiFont(size: 12, weight: .regular))
                    .accessibilityLabel("Search \(store.selectedSection.title)")
                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ClayTheme.secondary)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(9)
            .background(ClayTheme.sidebar, in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 14)
            .padding(.bottom, 13)

            Divider().overlay(ClayTheme.rule)

            if store.visibleDocuments.isEmpty {
                emptyList
            } else {
                List(selection: $store.selectedDocumentID) {
                    ForEach(store.visibleDocuments) { document in
                        ClayMacDocumentRow(
                            document: document,
                            isSelected: document.id == store.selectedDocumentID
                        )
                        .tag(document.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowBackground(Color.clear)
                        .contextMenu { documentContextMenu(document) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .tint(ClayTheme.selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ClayTheme.paper)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document list")
    }

    private var documentCountLabel: String {
        let count = store.visibleDocuments.count
        return count == 1 ? "1 document" : "\(count) documents"
    }

    private var emptyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.query.isEmpty ? "Nothing here yet" : "No matching documents")
                .font(ClayTheme.uiFont(size: 14, weight: .semibold))
            Text(emptyListDescription)
                .font(ClayTheme.uiFont(size: 13, weight: .regular))
                .foregroundStyle(ClayTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !store.query.isEmpty {
                Button("Clear Search") { store.query = "" }
                    .buttonStyle(.link)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyListDescription: String {
        if !store.query.isEmpty {
            return "Try another word, or clear your search."
        }
        if store.collectionFilter != nil {
            return "Documents in this collection will appear here."
        }
        return store.selectedSection == .scratchpads
            ? "A scratchpad can hold a passing thought, a rough draft, or something just for you."
            : "Move a scratchpad here when it’s ready to become a piece."
    }

    @ViewBuilder
    private var editor: some View {
        if let id = store.selectedDocument?.id {
            DocumentEditor(store: store, documentID: id)
                .id(id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 15) {
                SectionSymbol(section: store.selectedSection, size: 37)
                    .padding(.bottom, 4)
                Text(store.documents.isEmpty ? "A place to begin." : "Room for your writing.")
                    .font(ClayTheme.bodyFont(size: 34))
                    .multilineTextAlignment(.center)
                Text(store.documents.isEmpty
                     ? "Start a scratchpad. There’s no need to know where it will go."
                     : "Choose a document, or start with a fresh scratchpad.")
                    .font(ClayTheme.uiFont(size: 14, weight: .regular))
                    .foregroundStyle(ClayTheme.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
                Button {
                    actions.newScratchpad(in: store)
                } label: {
                    Label("New Scratchpad", systemImage: "square.and.pencil")
                        .font(ClayTheme.uiFont(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
            .padding(36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ClayTheme.paper)
        }
    }

    @ViewBuilder
    private func documentContextMenu(_ document: WritingDocument) -> some View {
        Button {
            store.togglePin(id: document.id)
        } label: {
            Label(document.pinned ? "Unpin" : "Pin", systemImage: document.pinned ? "pin.slash" : "pin")
        }
        Button {
            store.move(id: document.id, to: document.section == .pieces ? .scratchpads : .pieces)
        } label: {
            Label(document.section == .pieces ? "Move to Scratchpads" : "Move to Pieces", systemImage: "arrow.right")
        }
        Button {
            actions.export(id: document.id, from: store)
        } label: {
            Label("Export Markdown…", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            actions.trash(id: document.id, in: store)
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
    }
}

private struct ClayMacDocumentRow: View {
    let document: WritingDocument
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(document.displayTitle)
                    .font(ClayTheme.uiFont(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if document.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ClayTheme.amber)
                        .accessibilityLabel("Pinned")
                }
            }
            Text(preview)
                .font(ClayTheme.uiFont(size: 12, weight: .regular))
                .foregroundStyle(ClayTheme.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Text(document.updatedAt, style: .date)
                Text("·")
                Text(document.wordCount == 1 ? "1 word" : "\(document.wordCount) words")
            }
            .font(ClayTheme.uiFont(size: 10, weight: .regular))
            .foregroundStyle(ClayTheme.secondary)
            .lineLimit(1)
        }
        .foregroundStyle(ClayTheme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? ClayTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var preview: String {
        let trimmed = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? "An empty page, ready when you are."
            : String(trimmed.prefix(180)).replacingOccurrences(of: "\n", with: " ")
    }
}
