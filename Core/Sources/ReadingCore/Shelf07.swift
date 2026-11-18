import Foundation

// Version 0.7: search in the reading notes, the quote of the day, the "Just finished" card,
// and the titles owned both to read and to listen to.

extension Book {
    /// Owned both to read and to listen to (an ebook or own file, and an audiobook), in whatever stores.
    public var readAndListen: Bool {
        copies.contains { $0.isAudio } && copies.contains { !$0.isAudio }
    }
}

extension LibraryData {

    // MARK: Read + listen

    /// The titles owned both to read and to listen to, by title.
    public var pairs: [Book] {
        owned.filter(\.readAndListen).sorted { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
    }

    // MARK: Search in the notes

    /// The shown notes that hold every word asked for: in the note itself, its page, its kind's name, or the
    /// title or author of its book. Capitals and accents do not matter. No words = every note.
    /// `kind` narrows to one kind ("" = the notes whose kind was removed); nil = all kinds.
    public func notes(holding words: String, kind: String? = nil) -> [ReadingNote] {
        let asked = BookMatch.plain(words).split(whereSeparator: \.isWhitespace).map(String.init)
        let known = Set(noteKinds.map(\.id))
        return shownNotes.filter { note in
            if let kind {
                if kind.isEmpty ? known.contains(note.kind) : note.kind != kind { return false }
            }
            guard !asked.isEmpty else { return true }
            let book = self.book(note.bookID)
            let hay = BookMatch.plain([note.text, note.page ?? "", self.kind(note.kind).name,
                                       book?.title ?? "", book?.author ?? ""].joined(separator: " "))
            return asked.allSatisfy { hay.contains($0) }
        }
    }

    // MARK: Quote of the day

    /// One of the owner's own quotes, the same one all day and another one the next day. nil without a quote.
    public func quoteOfDay(on date: Date = Date(), calendar: Calendar = .current) -> ReadingNote? {
        let quotes = shownNotes.filter { $0.kind == "quote" }.sorted { ($0.made, $0.id) < ($1.made, $1.id) }
        guard !quotes.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return quotes[day % quotes.count]
    }

    // MARK: Just finished

    /// The book to ask "how was it?" about: finished within the last `days` days, no stars yet, and not one
    /// the owner answered "Not now" for (`skipped`, kept on the device). The latest finished first.
    public func justFinished(now: Date = Date(), days: Int = 14, skipped: Set<String> = []) -> Book? {
        let from = now.addingTimeInterval(-Double(days) * 86_400)
        return owned
            .filter { $0.status == .finished && $0.rating == nil && !skipped.contains($0.id) }
            .compactMap { book in book.finished.map { (book, $0) } }   // the day noted, never a guess from the last opening
            .filter { $0.1 >= from && $0.1 <= now.addingTimeInterval(86_400) }
            .max { ($0.1, $0.0.id) < ($1.1, $1.0.id) }?.0
    }

    // MARK: Send the notes that show

    /// Some notes as one tidy page: book by book, the oldest note first, each with its kind in front.
    public func notesPage(_ notes: [ReadingNote], heading: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        var lines = ["# \(heading)"]
        lines.append("\(notes.count == 1 ? "1 note" : "\(notes.count) notes") · \(Self.noteDay(now, calendar: calendar))")
        var order: [String] = []
        for note in notes where !order.contains(note.bookID) { order.append(note.bookID) }
        for id in order {
            guard let book = book(id) else { continue }
            lines.append("")
            lines.append("## \(book.title)" + (book.author.isEmpty ? "" : " — \(book.author)"))
            for note in notes.filter({ $0.bookID == id }).sorted(by: { ($0.made, $0.id) < ($1.made, $1.id) }) {
                let place = note.page.map { " (\(Self.pageWords($0)))" } ?? ""
                let text = note.text.replacingOccurrences(of: "\n", with: " ")
                let body = note.kind == "quote" ? "“\(Self.bare(text))”" : text
                lines.append("- \(kind(note.kind).name): \(body)\(place)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
