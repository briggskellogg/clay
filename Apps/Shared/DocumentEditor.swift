import SwiftUI
import ClayCore

@MainActor
struct DocumentEditor: View {
    @ObservedObject var store: ClayStore
    let documentID: UUID
    @AppStorage("clay.editor.size") private var textSize = 22.0
    @AppStorage("clay.editor.typeface") private var typeface = EditorTypeface.serif.rawValue
    @State private var reading = false
    @State private var showingExport = false
    @State private var exportFile: MarkdownFile?
    @State private var exportName = "Untitled"
    private enum EditorField: Hashable { case title, body, collection }
    @FocusState private var focusedField: EditorField?

    private var document: WritingDocument? { store.document(id: documentID) }
    private var face: EditorTypeface { EditorTypeface(rawValue: typeface) ?? .serif }
    private var controlSize: CGFloat {
        #if os(iOS)
        return 44
        #else
        return 36
        #endif
    }
    private var minimumEditorHeight: CGFloat {
        #if os(iOS)
        return 0
        #else
        return 170
        #endif
    }
    private var titleBinding: Binding<String> {
        Binding(get: { document?.title ?? "" },
                set: { store.updateTitle(id: documentID, value: $0) })
    }
    private var textBinding: Binding<String> {
        Binding(get: { document?.text ?? "" },
                set: { store.updateText(id: documentID, value: $0) })
    }
    private var collectionBinding: Binding<String> {
        Binding(get: { document?.collection ?? "" },
                set: { store.updateCollection(id: documentID, value: $0) })
    }

    var body: some View {
        Group {
            if let document {
                editor(document)
            } else {
                ContentUnavailableView("Choose some writing", systemImage: "doc.text",
                                       description: Text("Your scratchpads and pieces live here."))
                    .foregroundStyle(ClayTheme.secondary)
            }
        }
        .background(ClayTheme.paper)
        .foregroundStyle(ClayTheme.ink)
        .fileExporter(isPresented: $showingExport, document: exportFile,
                      contentType: MarkdownFile.contentType,
                      defaultFilename: exportName) { result in
            if case .failure(let error) = result {
                guard (error as? CocoaError)?.code != .userCancelled else { return }
                store.errorMessage = "Could not export this writing: \(error.localizedDescription)"
            }
        }
        .onChange(of: documentID) { _, _ in
            reading = false
            focusedField = nil
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        #endif
    }

    private func editor(_ document: WritingDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(document.section == .scratchpads ? "Scratchpad" : "Piece")
                    .font(ClayTheme.uiFont(size: 12))
                    .foregroundStyle(ClayTheme.secondary)
                Spacer(minLength: 8)
                Button {
                    store.togglePin(id: documentID)
                } label: {
                    Image(systemName: document.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(document.pinned ? ClayTheme.amber : ClayTheme.secondary)
                        .frame(minWidth: controlSize, minHeight: controlSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(document.pinned ? "Unpin document" : "Pin document")
                .help(document.pinned ? "Unpin document" : "Pin document")

                Button { reading.toggle() } label: {
                    Image(systemName: reading ? "pencil" : "book")
                        .foregroundStyle(ClayTheme.secondary)
                        .frame(minWidth: controlSize, minHeight: controlSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reading ? "Edit writing" : "Read writing")
                .help(reading ? "Edit writing" : "Read writing")

                Menu {
                    Picker("Typeface", selection: $typeface) {
                        ForEach(EditorTypeface.allCases) { face in
                            Text(face.title).tag(face.rawValue)
                        }
                    }
                    Menu("Text size") {
                        ForEach([18.0, 20.0, 22.0, 24.0, 28.0], id: \.self) { size in
                            Button {
                                textSize = size
                            } label: {
                                if textSize == size { Label("\(Int(size)) pt", systemImage: "checkmark") }
                                else { Text("\(Int(size)) pt") }
                            }
                        }
                    }
                    Divider()
                    Button("Export Markdown…", systemImage: "square.and.arrow.up") { beginExport(document) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(ClayTheme.secondary)
                        .frame(minWidth: controlSize, minHeight: controlSize)
                }
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif
                .accessibilityLabel("Writing options")
                .help("Writing options")
            }
            .padding(.bottom, 24)

            if reading {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text(document.displayTitle)
                            .font(ClayTheme.uiFont(size: 32, weight: .bold))
                            .textSelection(.enabled)
                        MarkdownReadingView(text: document.text, font: face.font(size: CGFloat(textSize)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                }
            } else {
                TextField("Untitled", text: titleBinding, axis: .vertical)
                    .font(ClayTheme.uiFont(size: 32, weight: .bold))
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .title)
                    .lineLimit(1...4)
                    .accessibilityLabel("Document title")
                    .padding(.bottom, 20)
                    .onSubmit { focusedField = .body }

                TextEditor(text: textBinding)
                    .font(face.font(size: CGFloat(textSize)))
                    .lineSpacing(7)
                    .scrollContentBackground(.hidden)
                    .background(ClayTheme.paper)
                    .focused($focusedField, equals: .body)
                    .accessibilityLabel("Document text")
                    .frame(minHeight: minimumEditorHeight, maxHeight: .infinity)
            }

            #if os(iOS)
            if focusedField != .body { footer(document) }
            #else
            footer(document)
            #endif
        }
        .padding(.horizontal, 26)
        .padding(.top, 15)
        .padding(.bottom, 16)
        .frame(maxWidth: 850, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footer(_ document: WritingDocument) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(ClayTheme.secondary)
                    .accessibilityHidden(true)
                TextField("Collection", text: collectionBinding)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .collection)
                    .font(ClayTheme.uiFont(size: 12))
                    .accessibilityLabel("Collection")
                    .frame(maxWidth: 180)
                Spacer(minLength: 0)
                Text("\(document.wordCount) \(document.wordCount == 1 ? "word" : "words")")
                    .font(ClayTheme.uiFont(size: 12))
                    .foregroundStyle(ClayTheme.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    saveStatus
                    Spacer(minLength: 10)
                    moveButton(document)
                }
                VStack(alignment: .leading, spacing: 10) {
                    moveButton(document)
                    saveStatus
                }
            }
        }
        .padding(.top, 14)
    }

    private var saveStatus: some View {
        Group {
            if store.saveStatus == "Save failed" {
                Button("Retry saving", systemImage: "arrow.clockwise") {
                    Task { await store.retrySave() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClayTheme.red)
            } else {
                Text(store.saveStatus)
                    .foregroundStyle(ClayTheme.secondary)
            }
        }
        .font(ClayTheme.uiFont(size: 11))
        .accessibilityLabel("Save status: \(store.saveStatus)")
    }

    private func moveButton(_ document: WritingDocument) -> some View {
        let destination: WritingSection = document.section == .scratchpads ? .pieces : .scratchpads
        return Button {
            store.move(id: documentID, to: destination)
        } label: {
            Label("Move to \(destination.title)", systemImage: "arrow.right")
                .font(ClayTheme.uiFont(size: 13))
        }
        .buttonStyle(.bordered)
        .tint(ClayTheme.secondary)
    }

    private func beginExport(_ document: WritingDocument) {
        guard let data = store.markdownData(for: document.id) else { return }
        exportFile = MarkdownFile(data: data)
        exportName = MarkdownFile.safeFilename(document.displayTitle)
        showingExport = true
    }
}
