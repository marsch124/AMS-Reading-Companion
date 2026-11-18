import Foundation

// Version 0.8: new shelves (New on the shelf, Waiting longest), your authors, the stores' collections as tags,
// put a book away, join two books, change several at once, the parts of the main screen, To do ticks.

/// A part of the main screen the owner can switch off.
public enum MainPart: String, CaseIterable, Sendable {
    case finished, whatNext, notes, quote, changes

    public var name: String {
        switch self {
        case .finished: return "Just finished card"
        case .whatNext: return "What next? card"
        case .notes: return "Reading notes line"
        case .quote: return "Quote of the day"
        case .changes: return "What changed line"
        }
    }
}

/// One author on the shelf, with how many of their books are owned, read and wished.
public struct AuthorLine: Identifiable, Equatable, Sendable {
    public var name: String
    public var owned: Int
    public var finished: Int
    public var reading: Int
    public var wishes: Int
    public var unread: Int { owned - finished - reading }
    public var id: String { name }
}

extension Book {
    /// The owner's tags, then the stores' collections the book stands in: each once, by its plain form.
    public var allTags: [String] {
        LibraryData.cleanTags(tags + copies.flatMap(\.collections))
    }
    /// The tags that come from a store's collection and are not also the owner's own: they cannot be taken off here.
    public var storeTags: [String] {
        let mine = Set(tags.map(LibraryData.tagKey))
        return LibraryData.cleanTags(copies.flatMap(\.collections)).filter { !mine.contains(LibraryData.tagKey($0)) }
    }
}

extension LibraryData {

    // MARK: New on the shelf, Waiting longest

    /// Owned books bought (else: first seen) within the last `days` days, the newest first.
    public func newBooks(now: Date = Date(), days: Int = 30) -> [Book] {
        let from = now.addingTimeInterval(-Double(days) * 86_400)
        return owned.map { ($0, $0.purchased ?? $0.added) }
            .filter { $0.1 >= from }
            .sorted { ($0.1, $0.0.id) > ($1.1, $1.0.id) }
            .map(\.0)
    }

    /// Not started, never opened, and bought a year or more ago: the longest wait first, at most `limit`.
    public func waitingLongest(now: Date = Date(), limit: Int = 20) -> [Book] {
        let before = now.addingTimeInterval(-365 * 86_400)
        return owned
            .filter { $0.status == .unread && $0.lastOpened == nil && ($0.purchased ?? .distantFuture) <= before }
            .sorted { ($0.purchased ?? .distantPast, $0.id) < ($1.purchased ?? .distantPast, $1.id) }
            .prefix(limit).map { $0 }
    }

    // MARK: Your authors

    /// Every author with a book that shows (told by the first author's last name and first letter), the one
    /// with the most owned books first. Books without an author are left out.
    public func authors() -> [AuthorLine] {
        var lines: [String: AuthorLine] = [:]
        var spell: [String: [String: Int]] = [:]
        for book in shown where !book.putAway && (!book.copies.isEmpty || book.wish) {
            let last = BookMatch.authorKey(book.author)
            guard !last.isEmpty else { continue }
            let key = last + "|" + (Self.firstInitial(book.author).map { String($0) } ?? "")
            var line = lines[key] ?? AuthorLine(name: book.author, owned: 0, finished: 0, reading: 0, wishes: 0)
            if book.copies.isEmpty { line.wishes += 1 } else {
                line.owned += 1
                if book.status == .finished { line.finished += 1 }
                if book.status == .reading { line.reading += 1 }
            }
            lines[key] = line
            spell[key, default: [:]][book.author, default: 0] += 1
        }
        // The spelling most of their books use.
        return lines.map { key, line in
            var line = line
            line.name = spell[key]?.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? line.name
            return line
        }
        .sorted { ($1.owned, BookMatch.authorKey($0.name), $0.name) < ($0.owned, BookMatch.authorKey($1.name), $1.name) }
    }

    // MARK: Put a book away

    public var putAwayBooks: [Book] {
        shown.filter(\.putAway).sorted { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
    }

    /// Puts owned books away (off every shelf and out of every count; the search still finds them), or takes them out again.
    public mutating func setPutAway(_ away: Bool, of ids: [String], now: Date = Date()) {
        for id in ids {
            guard let i = books.firstIndex(where: { $0.id == id && !$0.removed }), !books[i].copies.isEmpty,
                  books[i].putAway != away else { continue }
            books[i].putAway = away
            books[i].changed = now.wholeSeconds
        }
        if away {
            let gone = Set(ids)
            let next = upNext.filter { !gone.contains($0) }
            if next != upNext { upNext = next; upNextChanged = now.wholeSeconds }
        }
    }

    // MARK: Join two books

    /// The books `id` could be the same as: every other shown book, the likeliest first (same author, then by title).
    public func joinChoices(for id: String) -> [Book] {
        guard let book = book(id) else { return [] }
        let author = BookMatch.authorKey(book.author)
        return shown.filter { $0.id != id && (!$0.copies.isEmpty || $0.wish) }
            .sorted { a, b in
                let sa = BookMatch.authorKey(a.author) == author && !author.isEmpty ? 0 : 1
                let sb = BookMatch.authorKey(b.author) == author && !author.isEmpty ? 0 : 1
                return (sa, BookMatch.titleKey(a.title), a.id) < (sb, BookMatch.titleKey(b.title), b.id)
            }
    }

    /// Makes `other` part of `id`: its copies, notes, tags and place in Up next move over, and what `id` lacks
    /// (stars, note, cover, series, the finishing day) is taken from it. `other` leaves the shelf for good;
    /// the stores' lists find its copies on `id` from then on. Returns false when nothing was joined.
    @discardableResult
    public mutating func join(_ otherID: String, into id: String, now: Date = Date()) -> Bool {
        guard otherID != id,
              let i = books.firstIndex(where: { $0.id == id && !$0.removed }),
              let o = books.firstIndex(where: { $0.id == otherID && !$0.removed }) else { return false }
        let now = now.wholeSeconds
        let other = books[o]
        var book = books[i]
        for copy in other.copies where !book.copies.contains(where: { $0.id == copy.id }) { book.copies.append(copy) }
        if !book.copies.isEmpty { book.wish = false }
        book.tags = Self.cleanTags(book.tags + other.tags)
        if book.rating == nil { book.rating = other.rating }
        if (book.note ?? "").isEmpty { book.note = other.note }
        else if let more = other.note, !more.isEmpty, more != book.note { book.note = (book.note ?? "") + "\n" + more }
        if book.coverURL == nil { book.coverURL = other.coverURL }
        if book.series == nil { book.series = other.series; book.seriesNumber = other.seriesNumber }
        if book.about == nil { book.about = other.about }
        if book.language == nil { book.language = other.language }
        // The further along of the two: finished beats reading beats not read.
        func rank(_ s: ReadStatus) -> Int { s == .finished ? 2 : (s == .reading ? 1 : 0) }
        if rank(other.status) > rank(book.status) {
            book.status = other.status; book.statusByHand = true
            book.finished = other.finished ?? other.lastOpened
        }
        if let opened = other.lastOpened, opened > (book.lastOpened ?? .distantPast) { book.lastOpened = opened }
        if let p = other.progress, p > (book.progress ?? 0) { book.progress = p }
        book.added = min(book.added, other.added)
        book.putAway = book.putAway && other.putAway
        book.changed = now
        books[i] = book
        books[o].copies = []
        books[o].wish = false
        books[o].removed = true
        books[o].changed = now
        for n in notes.indices where notes[n].bookID == otherID {
            notes[n].bookID = id
            notes[n].changed = now
        }
        if upNext.contains(otherID) {
            upNext = upNext.map { $0 == otherID ? id : $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            upNextChanged = now
        }
        return true
    }

    // MARK: Change several at once

    public mutating func setStatus(_ status: ReadStatus, ofAll ids: [String], now: Date = Date()) {
        for id in ids { setStatus(status, of: id, now: now) }
    }

    /// Adds one tag to every book named (a book that has it already stays as it is).
    public mutating func addTag(_ tag: String, toAll ids: [String], now: Date = Date()) {
        guard let clean = Self.cleanTags([tag]).first else { return }
        for id in ids {
            guard let book = books.first(where: { $0.id == id && !$0.removed }) else { continue }
            setTags(book.tags + [clean], of: id, now: now)
        }
    }

    /// Puts every owned book named at the end of Up next, in the order given (one that is there already stays).
    public mutating func addUpNext(all ids: [String], now: Date = Date()) {
        for id in ids { addUpNext(id, now: now) }
    }

    // MARK: The parts of the main screen

    public func shows(_ part: MainPart) -> Bool { !hiddenParts.contains(part.rawValue) }

    public mutating func setHiddenParts(_ parts: [MainPart], now: Date = Date()) {
        let names = MainPart.allCases.filter(parts.contains).map(\.rawValue)
        guard names != hiddenParts else { return }
        hiddenParts = names
        shelvesChanged = now.wholeSeconds
    }

    // MARK: To do ticks

    /// Ticks a note off, or opens it again.
    public mutating func setDone(_ done: Bool, note id: String, now: Date = Date()) {
        guard let i = notes.firstIndex(where: { $0.id == id && !$0.removed }), notes[i].done != done else { return }
        notes[i].done = done
        notes[i].changed = now.wholeSeconds
    }

    /// The To do notes that are not ticked off yet.
    public var openTodos: [ReadingNote] { shownNotes.filter { $0.kind == "todo" && !$0.done } }
}
