import ReadingCore
import SwiftUI

/// One reading note as a row: the dot of its kind, the words, and a small line saying what and when.
struct NoteRow: View {
    @EnvironmentObject private var model: ReadingModel
    let note: ReadingNote
    /// Name the book in the small line (the notebook), or not (the book's own page).
    var namesBook = false
    /// Name the kind in the small line. Off where the notes already stand under their kind's heading.
    var namesKind = true

    var body: some View {
        let kind = model.data.kind(note.kind)
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle()
                .fill(Theme.text(kind.colour))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(words)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line(kind))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// A quote stands in quotation marks, unless the owner typed them himself.
    private var words: String {
        guard note.kind == "quote", let first = note.text.first, !"\"“„«".contains(first) else { return note.text }
        return "“\(note.text)”"
    }

    private func line(_ kind: NoteKind) -> String {
        var parts: [String] = []
        if namesKind { parts.append(kind.name) }
        if namesBook, let book = model.data.book(note.bookID) { parts.append(book.title) }
        if let page = note.page { parts.append(page.allSatisfy(\.isNumber) ? "page \(page)" : page) }
        parts.append(Self.day(note.made))
        return parts.joined(separator: " · ")
    }

    /// "today", "yesterday", "14 Nov", and with the year when it is not this year.
    static func day(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let before = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: before) { return "yesterday" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now) ? "d MMM" : "d MMM yyyy"
        return f.string(from: date)
    }
}

/// The notebook: every reading note. Either all notes with the newest first and the kinds on top to narrow them
/// down, or book by book.
struct NotesPage: View {
    enum Arrangement { case notebook, byBook }
    /// The owner's pick of 18 Nov 2026.
    static let arrangement: Arrangement = .notebook

    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    /// The kind shown; nil = all.
    @State private var kind: String?
    @State private var draft: NoteDraft?

    private let colour = "orange"

    var body: some View {
        let notes = model.data.shownNotes
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if notes.isEmpty {
                        Text("Nothing noted yet. Press New note, then type, speak, or take a photo of the page.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("notes-empty")
                    } else {
                        switch Self.arrangement {
                        case .notebook: notebook(notes)
                        case .byBook: byBook(notes)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Reading notes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("notes-done")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !model.readOnly, let book = model.data.noteBook ?? model.data.upNextBooks.first ?? model.data.owned.first {
                        Button("New note") { draft = NoteDraft(bookID: book.id) }
                            .buttonStyle(FilledButton(colour: colour))
                            .accessibilityIdentifier("notes-new")
                    }
                }
            }
        }
        .accessibilityIdentifier("notes-page")
        .sheet(item: $draft) { NoteEditPage(draft: $0) }
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }

    // MARK: All notes, the newest first

    @ViewBuilder
    private func notebook(_ notes: [ReadingNote]) -> some View {
        let kinds = model.data.kindsInUse()
        let known = Set(model.data.noteKinds.map(\.id))
        ChipFlow {
            Chip(title: "All", count: notes.count, colour: colour, on: kind == nil) { kind = nil }
                .accessibilityIdentifier("notes-kind-all")
            ForEach(kinds, id: \.kind.id) { entry in
                if entry.count > 0 {
                    Chip(title: entry.kind.name, count: entry.count, colour: colour, on: kind == entry.kind.id, dot: entry.kind.colour) {
                        kind = kind == entry.kind.id ? nil : entry.kind.id
                    }
                    .accessibilityIdentifier("notes-kind-\(entry.kind.id.isEmpty ? "other" : entry.kind.id)")
                }
            }
        }
        let shown = notes.filter { note in
            guard let kind else { return true }
            return kind.isEmpty ? !known.contains(note.kind) : note.kind == kind
        }
        ForEach(shown) { note in
            Button { draft = NoteDraft(bookID: note.bookID, noteID: note.id) } label: {
                NoteRow(note: note, namesBook: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(model.readOnly)
            .accessibilityIdentifier("notes-note-\(note.id)")
        }
    }

    // MARK: Book by book

    @ViewBuilder
    private func byBook(_ notes: [ReadingNote]) -> some View {
        // The books in the order of their newest note; the book being read now first.
        let reading = model.data.noteBook?.id
        let ids = notes.map(\.bookID).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .sorted { a, b in (a == reading ? 0 : 1) < (b == reading ? 0 : 1) }
        ForEach(ids, id: \.self) { id in
            if let book = model.data.book(id) {
                let mine = notes.filter { $0.bookID == id }
                HStack(alignment: .center, spacing: 8) {
                    CoverView(book: book, width: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(book.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text(colour))
                            .lineLimit(2)
                        Text([book.author, mine.count == 1 ? "1 note" : "\(mine.count) notes"].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    ShareLink(item: model.data.notesPage(of: id), subject: Text("Notes on “\(book.title)”")) {
                        Text("Send")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text(colour))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notes-send-\(id)")
                }
                .padding(.top, 6)
                ForEach(mine) { note in
                    Button { draft = NoteDraft(bookID: id, noteID: note.id) } label: { NoteRow(note: note) }
                        .buttonStyle(.plain)
                        .disabled(model.readOnly)
                        .accessibilityIdentifier("notes-note-\(note.id)")
                }
            }
        }
    }
}
