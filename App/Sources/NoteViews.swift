import ReadingCore
import AMSIcons
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
        let isTodo = note.kind == "todo"
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if isTodo {
                tickBox(kind)
            } else {
                Circle()
                    .fill(Theme.text(kind.colour))
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(words)
                    .strikethrough(isTodo && note.done)
                    .foregroundStyle(isTodo && note.done ? Color.secondary : Color.primary)
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

    /// The hand-drawn box of a To do. It is its own tap target (a high-priority tap, not a Button), so a tap on it
    /// ticks the note and never reaches the Button around the row that opens the note.
    private func tickBox(_ kind: NoteKind) -> some View {
        TickBoxMark(done: note.done)
            .stroke(note.done ? Theme.text(kind.colour) : Color.secondary,
                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .padding(4)
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { if !model.readOnly { model.setDone(!note.done, note: note.id) } })
            .accessibilityElement()
            .accessibilityLabel(note.done ? "Done" : "Not done")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if !model.readOnly { model.setDone(!note.done, note: note.id) } }
            .accessibilityIdentifier("note-tick-\(note.id)")
            .padding(-4)
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

/// A box on a 24-point grid; with `done`, a tick stands in it.
struct TickBoxMark: Shape {
    var done: Bool
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.minX + 3.5 * k, y: rect.minY + 3.5 * k, width: 17 * k, height: 17 * k),
                         cornerSize: CGSize(width: 4 * k, height: 4 * k))
        if done {
            p.move(to: pt(8, 12.4))
            p.addLine(to: pt(11, 15.4))
            p.addLine(to: pt(16.4, 8.6))
        }
        return p
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
    /// The words looked for in the notes.
    @State private var words = ""

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
        ChipFlow {
            Chip(title: "All", count: notes.count, colour: colour, on: kind == nil) { kind = nil }
                .accessibilityIdentifier("notes-kind-all")
            ForEach(kinds, id: \.kind.id) { entry in
                if entry.count > 0 {
                    let doneCount = entry.kind.id == "todo" ? notes.filter { $0.kind == "todo" && $0.done }.count : 0
                    Chip(title: entry.kind.name, count: doneCount > 0 ? entry.count - doneCount : entry.count,
                         colour: colour, on: kind == entry.kind.id, dot: entry.kind.colour) {
                        kind = kind == entry.kind.id ? nil : entry.kind.id
                    }
                    .accessibilityIdentifier("notes-kind-\(entry.kind.id.isEmpty ? "other" : entry.kind.id)")
                }
            }
        }
        let found = model.data.notes(holding: words, kind: kind)
        // With the To do chip chosen, the open ones stand before the done ones (the order inside each is kept).
        let shown = kind == "todo" ? found.filter { !$0.done } + found.filter(\.done) : found
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                AppMarkView(.search, size: 15, colour: .secondary)
                TextField("Search your notes", text: $words)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("notes-search")
                if !words.isEmpty {
                    Button("Clear") { words = "" }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text(colour))
                        .accessibilityIdentifier("notes-search-clear")
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.plate, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            if !shown.isEmpty {
                ShareLink(item: model.data.notesPage(shown, heading: sendHeading), subject: Text(sendHeading)) {
                    Text("Send these")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text(colour))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("notes-send-shown")
            }
        }
        if shown.isEmpty {
            Text(words.isEmpty ? "No note of this kind." : "No note holds “\(words)”.")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("notes-none-found")
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

    /// The heading of the page "Send these" makes: the kind that shows, and the words looked for.
    private var sendHeading: String {
        var head = kind.map { model.data.kind($0).name } ?? "Reading notes"
        let asked = words.trimmingCharacters(in: .whitespaces)
        if !asked.isEmpty { head += " · “\(asked)”" }
        return head
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
