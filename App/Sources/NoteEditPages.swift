import AMSIcons
import ReadingCore
import SwiftUI

// The reading-note pages: write or change a note, pick its book, and the kinds of notes.

private let noteColour = "orange"

/// One small outlined button (or a full-colour one when `on`), the same height as a chip.
private struct SmallOutlined: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .foregroundStyle(on ? Color.white : Theme.text(noteColour))
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Theme.fill(noteColour) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.text(noteColour).opacity(on ? 0 : 0.45), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A compact book row: small cover, title, author.
private struct BookLine: View {
    let book: Book
    var body: some View {
        HStack(spacing: 10) {
            CoverView(book: book, width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(book.title).font(.body.weight(.semibold)).lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Write or change a note

struct NoteEditPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let draft: NoteDraft

    @State private var bookID: String
    @State private var kindID: String
    @State private var text: String
    @State private var page: String
    @State private var pickingBook = false
    @State private var editingKinds = false
    @State private var confirmRemove = false
    @State private var baseText = ""
    @StateObject private var dictation = Dictation()
    @FocusState private var typing: Bool

    init(draft: NoteDraft) {
        self.draft = draft
        _bookID = State(initialValue: draft.bookID)
        _kindID = State(initialValue: "")
        _text = State(initialValue: "")
        _page = State(initialValue: "")
    }

    @State private var loaded = false

    private var existing: ReadingNote? { draft.noteID.flatMap { model.data.note($0) } }
    private var book: Book? { model.data.book(bookID) }
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.data.noteKinds.contains { $0.id == kindID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if book == nil {
                    Text("This book is not on your shelf any more.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(16)
                        .accessibilityIdentifier("note-book-gone")
                } else {
                    content
                }
            }
            .navigationTitle(draft.noteID == nil ? "New note" : "Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("note-cancel")
                }
                if book != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .buttonStyle(FilledButton(colour: noteColour))
                            .keyboardShortcut(.defaultAction)
                            .disabled(!canSave)
                            .accessibilityIdentifier("note-save")
                    }
                }
            }
        }
        .onAppear { load() }
        .onDisappear { dictation.stop() }
        .onChange(of: dictation.text) { _, spoken in
            guard dictation.running || !spoken.isEmpty else { return }
            text = Self.join(baseText, spoken)
        }
        .sheet(isPresented: $pickingBook) { NoteBookPicker(bookID: $bookID) }
        .sheet(isPresented: $editingKinds) { NoteKindsPage() }
        .accessibilityIdentifier("note-page")
        #if os(macOS)
        .frame(width: 460, height: 560)
        #endif
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let note = existing {
            bookID = note.bookID
            text = note.text
            page = note.page ?? ""
            kindID = model.data.noteKinds.contains { $0.id == note.kind } ? note.kind : ""
        } else {
            kindID = model.data.noteKinds.first?.id ?? ""
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let book {
                Button { pickingBook = true } label: { BookLine(book: book) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("note-book")
            }
            kinds
            editor
            actions
            if let trouble = dictation.trouble {
                Text(trouble).font(.footnote).foregroundStyle(Theme.text("red"))
                    .accessibilityIdentifier("note-trouble")
            }
            TextField("Page (if you like)", text: $page)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("note-page-field")
            if let note = existing { existingRow(note) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var kinds: some View {
        ChipFlow {
            ForEach(model.data.noteKinds) { kind in
                Chip(title: kind.name, colour: noteColour, on: kindID == kind.id, dot: kind.colour) { kindID = kind.id }
                    .accessibilityIdentifier("note-kind-\(kind.id)")
            }
            Button { editingKinds = true } label: {
                Text("Your own…")
                    .font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundStyle(Theme.text(noteColour))
                    .overlay(Capsule().stroke(Theme.text(noteColour).opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("note-kinds-edit")
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .focused($typing)
            .scrollContentBackground(.hidden)
            .padding(4)
            .frame(minHeight: 110, maxHeight: .infinity)
            .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What do you want to keep?")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("note-text")
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { typing = true } label: { Text("Type") }
                .buttonStyle(SmallOutlined())
                .accessibilityIdentifier("note-type")
            Button { toggleSpeak() } label: { Text(dictation.running ? "Stop" : "Speak") }
                .buttonStyle(SmallOutlined(on: dictation.running))
                .accessibilityIdentifier("note-speak")
            PagePhotoButton(colour: noteColour) { added in
                text = Self.join(text, added)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func existingRow(_ note: ReadingNote) -> some View {
        HStack(spacing: 8) {
            ShareLink(item: model.data.noteText(note)) {
                HStack(spacing: 5) {
                    AppMarkView(.share, size: 16, colour: Theme.text(noteColour))
                    Text("Share")
                }
            }
            .buttonStyle(SmallOutlined())
            .accessibilityIdentifier("note-share")
            Button { confirmRemove = true } label: {
                Text("Remove note").foregroundStyle(Theme.text("red"))
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("note-remove")
        }
        .confirmationDialog("Remove this note?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.removeNote(note.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toggleSpeak() {
        if dictation.running {
            dictation.stop()
        } else {
            baseText = text
            dictation.text = ""
            dictation.start(language: book?.language)
        }
    }

    private static func join(_ first: String, _ second: String) -> String {
        let a = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = second.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty { return first }
        return a + " " + b
    }

    private func save() {
        dictation.stop()
        let pageValue = page.trimmingCharacters(in: .whitespaces)
        if let note = existing {
            model.changeNote(note.id, text: text, kind: kindID, page: pageValue.isEmpty ? nil : pageValue, bookID: bookID)
        } else {
            _ = model.addNote(bookID: bookID, text: text, kind: kindID, page: pageValue.isEmpty ? nil : pageValue)
        }
        dismiss()
    }
}

// MARK: - Choose another book

struct NoteBookPicker: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @Binding var bookID: String
    @State private var query = ""
    @FocusState private var focused: Bool

    private var typed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AppMarkView(.search, size: 18).foregroundStyle(Theme.text(noteColour))
                    TextField("Title, author or series", text: $query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("notebook-search")
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if typed.isEmpty {
                            section("Reading now", model.data.shelf("reading")?.books ?? [], colour: "purple")
                            section("Up next", model.data.upNextBooks, colour: "indigo")
                        } else {
                            let found = model.data.find(typed)
                            if found.isEmpty {
                                Text("Not on your shelf.").foregroundStyle(.secondary)
                                    .accessibilityIdentifier("notebook-none")
                            }
                            ForEach(found) { row($0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .navigationTitle("Choose a book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("notebook-cancel")
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    @ViewBuilder
    private func section(_ title: String, _ books: [Book], colour: String) -> some View {
        if !books.isEmpty {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text(colour))
                .padding(.top, 4)
            ForEach(books) { row($0) }
        }
    }

    private func row(_ book: Book) -> some View {
        Button {
            bookID = book.id
            dismiss()
        } label: { BookLine(book: book) }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notebook-row-\(book.id)")
    }
}

// MARK: - Kinds of notes

struct NoteKindsPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var removing: NoteKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.data.noteKinds) { kind in
                        // The last kind stays: a note needs one.
                        KindRow(kind: kind, canRemove: model.data.noteKinds.count > 1) { removing = kind }
                            .disabled(model.readOnly)
                    }
                    HStack(spacing: 8) {
                        TextField("New kind", text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { add() }
                            .accessibilityIdentifier("kind-new")
                        Button("Add") { add() }
                            .buttonStyle(FilledButton(colour: noteColour))
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("kind-add")
                    }
                    .padding(.top, 4)
                    .disabled(model.readOnly)
                    Text("Quote, Thought, To do and Word to look up are the start. Rename them, remove them or add your own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .navigationTitle("Kinds of notes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(colour: noteColour))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("kinds-done")
                }
            }
            .confirmationDialog("Remove this kind? Its notes stay and stand under Other.",
                                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let kind = removing { model.removeKind(kind.id) }
                    removing = nil
                }
                Button("Cancel", role: .cancel) { removing = nil }
            }
        }
        .accessibilityIdentifier("kinds-page")
        #if os(macOS)
        .frame(width: 440, height: 440)
        #endif
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        model.addKind(name)
        newName = ""
    }
}

private struct KindRow: View {
    @EnvironmentObject private var model: ReadingModel
    let kind: NoteKind
    var canRemove = true
    let onRemove: () -> Void
    @State private var name: String
    @FocusState private var focused: Bool

    init(kind: NoteKind, canRemove: Bool = true, onRemove: @escaping () -> Void) {
        self.kind = kind
        self.canRemove = canRemove
        self.onRemove = onRemove
        _name = State(initialValue: kind.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.text(kind.colour)).frame(width: 10, height: 10)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: focused) { _, now in if !now { commit() } }
                .accessibilityIdentifier("kind-name-\(kind.id)")
            Button(action: onRemove) {
                ControlMarkView(.minusCircle, size: 20, colour: Theme.text("red"))
            }
            .buttonStyle(.plain)
            .opacity(canRemove ? 1 : 0)
            .disabled(!canRemove)
            .accessibilityLabel("Remove \(kind.name)")
            .accessibilityIdentifier("kind-remove-\(kind.id)")
        }
        .onChange(of: kind.name) { _, new in if !focused { name = new } }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { name = kind.name; return }
        if trimmed != kind.name { model.renameKind(kind.id, to: trimmed) }
    }
}
