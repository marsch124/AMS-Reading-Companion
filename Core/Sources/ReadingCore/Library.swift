import Foundation

/// How two entries are told to be the same book: by title and first author, written plainly.
public enum BookMatch {
    private static let articles: Set<String> = ["the", "a", "an", "der", "die", "das", "en", "ett", "den", "det"]

    static func plain(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    /// The title without its subtitle, capitals, accents, punctuation and a leading "The".
    public static func titleKey(_ title: String) -> String {
        var t = plain(title)
        for mark in [":", " (", " [", " - ", " – ", " — "] {
            if let r = t.range(of: mark), t.distance(from: t.startIndex, to: r.lowerBound) >= 3 {
                t = String(t[..<r.lowerBound])
            }
        }
        var words = t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.count > 1, let first = words.first, articles.contains(first) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    /// The first author's last name: "Herbert, Frank", "Frank Herbert" and "Frank Herbert & Brian Herbert" all give "herbert".
    public static func authorKey(_ author: String) -> String {
        var a = plain(author)
        for mark in [";", "&", " and ", " och ", " und "] {
            if let r = a.range(of: mark) { a = String(a[..<r.lowerBound]) }
        }
        let parts = a.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let name: String
        if parts.count >= 2, !parts[0].contains(" ") {
            name = parts[0]                               // "herbert, frank"
        } else {
            name = parts.first?.split(separator: " ").last.map(String.init) ?? ""
        }
        return name.filter { $0.isLetter }
    }

    public static func same(title a: String, author aa: String, title b: String, author ba: String) -> Bool {
        let ta = titleKey(a)
        guard !ta.isEmpty, ta == titleKey(b) else { return false }
        let ka = authorKey(aa), kb = authorKey(ba)
        return ka.isEmpty || kb.isEmpty || ka == kb
    }
}

/// One shelf on the main screen.
public struct Shelf: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var colour: String
    public var note: String?
    public var books: [Book]
}

public struct ImportSummary: Equatable, Sendable {
    public var added = 0
    public var updated = 0
    public var removed = 0
    public var samples = 0
    public init() {}
}

extension LibraryData {
    /// The books that show: everything not taken off the shelf.
    public var shown: [Book] { books.filter { !$0.removed } }
    public var owned: [Book] { shown.filter { !$0.copies.isEmpty } }

    public func book(_ id: String) -> Book? { books.first { $0.id == id && !$0.removed } }

    // MARK: Taking in a store's list

    /// Takes in what one reader found.
    /// `complete` = the list is the store's whole list, so a book of that reader that is no longer in it leaves
    /// the shelf. An empty list never removes anything (a signed-out store app must not empty the shelf).
    @discardableResult
    public mutating func take(_ imported: [ImportedBook], source: CopySource, complete: Bool, now: Date = Date()) -> ImportSummary {
        var summary = ImportSummary()
        let now = now.wholeSeconds
        let items = imported.filter { !$0.isSample && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        summary.samples = imported.count - items.count

        // What a reader marks as a sample or a built-in item never belongs on the shelf. If an earlier read put it
        // there (before the reader knew better), it leaves now.
        let notBooks = Set(imported.filter(\.isSample).map { "\($0.store.rawValue):\($0.storeID)" })
        if !notBooks.isEmpty {
            for i in books.indices where !books[i].removed {
                let before = books[i].copies.count
                books[i].copies.removeAll { $0.source == source && notBooks.contains($0.id) }
                guard books[i].copies.count != before else { continue }
                summary.removed += before - books[i].copies.count
                books[i].changed = now
                if books[i].copies.isEmpty && !books[i].wish { books[i].removed = true }
            }
        }
        guard !items.isEmpty else { return summary }

        var seen = Set<String>()
        for item in items {
            let copy = BookCopy(store: item.store, storeID: item.storeID, kind: item.kind, lockFree: item.lockFree,
                                filePath: item.filePath, purchased: item.purchased?.wholeSeconds, source: source)
            seen.insert(copy.id)

            if let i = books.firstIndex(where: { b in b.copies.contains { $0.id == copy.id } }) {
                // Known copy. A book the owner took off the shelf stays off.
                guard !books[i].removed else { continue }
                let before = books[i]
                if let c = books[i].copies.firstIndex(where: { $0.id == copy.id }) { books[i].copies[c] = copy }
                if books[i].copies.count == 1 { books[i].title = item.title; books[i].author = item.author }
                fill(&books[i], from: item)
                if books[i] != before { books[i].changed = now; summary.updated += 1 }
            } else if let i = books.firstIndex(where: { b in
                !b.removed && BookMatch.same(title: b.title, author: b.author, title: item.title, author: item.author)
            }) {
                // The same title from another store, a wish that is now owned, or a book first added by hand.
                books[i].copies.removeAll { $0.source == .hand && $0.store == copy.store && $0.isAudio == copy.isAudio }
                books[i].copies.append(copy)
                books[i].wish = false
                if books[i].author.isEmpty { books[i].author = item.author }
                fill(&books[i], from: item)
                books[i].changed = now
                summary.added += 1
            } else if let i = books.firstIndex(where: { $0.id == copy.id }) {
                // A book that once left this store's list and is back: the same book again, with what the owner set on it.
                books[i].removed = false
                books[i].copies = [copy]
                books[i].title = item.title
                books[i].author = item.author
                fill(&books[i], from: item)
                books[i].changed = now
                summary.added += 1
            } else {
                var book = Book(id: copy.id, title: item.title, author: item.author, copies: [copy], added: now, changed: now)
                fill(&book, from: item)
                books.append(book)
                summary.added += 1
            }
        }

        if complete {
            for i in books.indices where !books[i].removed {
                let before = books[i].copies.count
                books[i].copies.removeAll { $0.source == source && !seen.contains($0.id) }
                guard books[i].copies.count != before else { continue }
                summary.removed += before - books[i].copies.count
                books[i].changed = now
                if books[i].copies.isEmpty && !books[i].wish { books[i].removed = true }
            }
        }
        return summary
    }

    private func fill(_ book: inout Book, from item: ImportedBook) {
        if book.coverURL == nil, let cover = item.coverURL, !cover.isEmpty { book.coverURL = cover }
        if let series = item.series, !series.isEmpty, book.series == nil {
            book.series = series
            book.seriesNumber = item.seriesNumber
        }
        if let opened = item.lastOpened?.wholeSeconds, opened > (book.lastOpened ?? .distantPast) { book.lastOpened = opened }
        if let p = item.progress, p > (book.progress ?? 0) { book.progress = min(p, 1) }
        guard !book.statusByHand else { return }
        if item.finished {
            book.status = .finished
        } else if (item.progress ?? 0) >= 0.02, book.status == .unread {
            book.status = .reading
        }
    }

    // MARK: What the owner does by hand

    public mutating func setStatus(_ status: ReadStatus, of id: String, now: Date = Date()) {
        let now = now.wholeSeconds
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].status = status
        books[i].statusByHand = true
        books[i].changed = now
    }

    /// The owned book with this title, if there is one: the check before buying or wishing.
    public func ownedMatch(title: String, author: String) -> Book? {
        owned.first { BookMatch.same(title: $0.title, author: $0.author, title: title, author: author) }
    }

    /// Adds a book by hand: a wish (`store` nil) or a copy in a store. Returns the book it ended up on.
    @discardableResult
    public mutating func add(title: String, author: String, store: BookStore?, now: Date = Date(),
                             newID: String = UUID().uuidString) -> Book? {
        let now = now.wholeSeconds
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let match = books.firstIndex { !$0.removed && BookMatch.same(title: $0.title, author: $0.author, title: title, author: author) }
        guard let store else {
            if let i = match { return books[i] }            // already owned or already wished: nothing to add
            let book = Book(id: "wish:\(newID)", title: title, author: author, wish: true, added: now, changed: now)
            books.append(book)
            return book
        }
        let copy = BookCopy(store: store, storeID: "hand-\(newID)", lockFree: store == .own, purchased: now, source: .hand)
        if let i = match {
            if !books[i].copies.contains(where: { $0.store == store }) { books[i].copies.append(copy) }
            books[i].wish = false
            books[i].changed = now
            return books[i]
        }
        let book = Book(id: copy.id, title: title, author: author, copies: [copy], added: now, changed: now)
        books.append(book)
        return book
    }

    /// Only a wish, a book added by hand or a Kindle book can be taken off by hand:
    /// an Apple Books or Kobo book would come back with that store's next list.
    public func canRemove(_ book: Book) -> Bool {
        book.copies.allSatisfy { $0.source == .hand || $0.source == .kindle || $0.source == .file }
    }

    public mutating func remove(_ id: String, now: Date = Date()) {
        let now = now.wholeSeconds
        guard let i = books.firstIndex(where: { $0.id == id }), canRemove(books[i]) else { return }
        books[i].removed = true
        books[i].wish = false
        books[i].changed = now
    }

    // MARK: Shelves and search

    public func shelves() -> [Shelf] {
        var out: [Shelf] = []
        let owned = self.owned
        let byTitle: (Book, Book) -> Bool = { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
        let recent: (Book, Book) -> Bool = { ($0.lastOpened ?? $0.changed) > ($1.lastOpened ?? $1.changed) }

        // "Reading now" is what was opened lately: a book the store says was started but that has not been opened
        // in the 90 days before the latest reading goes back to "Not read yet". A status set by hand always counts.
        let latest = owned.compactMap(\.lastOpened).max() ?? Date()
        let current: (Book) -> Bool = { book in
            guard book.status == .reading else { return false }
            if book.statusByHand { return true }
            guard let opened = book.lastOpened else { return true }   // the store gave no day: take its word
            return latest.timeIntervalSince(opened) <= 90 * 86_400
        }
        let reading = owned.filter(current).sorted(by: recent)
        if !reading.isEmpty { out.append(Shelf(id: "reading", title: "Reading now", colour: "purple", note: nil, books: reading)) }

        let unread = owned.filter { $0.status == .unread || ($0.status == .reading && !current($0)) }
            .sorted { ($0.purchased ?? .distantPast, $1.title) > ($1.purchased ?? .distantPast, $0.title) }
        if !unread.isEmpty { out.append(Shelf(id: "unread", title: "Not read yet · \(unread.count)", colour: "red", note: nil, books: unread)) }

        var series: [String: [Book]] = [:]
        var names: [String: String] = [:]
        for book in owned {
            guard let name = book.series?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            let key = BookMatch.plain(name)
            series[key, default: []].append(book)
            names[key] = names[key] ?? name
        }
        for key in series.keys.sorted() {
            guard let members = series[key], members.count >= 2 else { continue }
            let sorted = members.sorted { ($0.seriesNumber ?? .infinity, $0.title) < ($1.seriesNumber ?? .infinity, $1.title) }
            out.append(Shelf(id: "series-\(key)", title: names[key] ?? key, colour: "green",
                             note: Self.seriesNote(sorted), books: sorted))
        }

        let lockFree = owned.filter(\.isLockFree).sorted(by: byTitle)
        if !lockFree.isEmpty { out.append(Shelf(id: "lockfree", title: "Lock-free · \(lockFree.count)", colour: "teal", note: nil, books: lockFree)) }

        let audio = owned.filter(\.isAudio).sorted(by: byTitle)
        if !audio.isEmpty { out.append(Shelf(id: "audio", title: "Audiobooks · \(audio.count)", colour: "amber", note: nil, books: audio)) }

        let finished = owned.filter { $0.status == .finished }.sorted(by: recent)
        if !finished.isEmpty { out.append(Shelf(id: "finished", title: "Finished · \(finished.count)", colour: "grey", note: nil, books: finished)) }

        let wishes = shown.filter(\.wish).sorted { $0.added > $1.added }
        out.append(Shelf(id: "wish", title: wishes.isEmpty ? "Wish list" : "Wish list · \(wishes.count)", colour: "blue",
                         note: wishes.isEmpty ? "Nothing wished for yet." : nil, books: wishes))
        return out
    }

    /// "3 owned · missing 2 and 4". Gaps are only known below the highest number that is owned.
    static func seriesNote(_ books: [Book]) -> String {
        var note = "\(books.count) owned"
        let numbers = Set(books.compactMap(\.seriesNumber).filter { $0 >= 1 && $0 == $0.rounded() }.map { Int($0) })
        guard let top = numbers.max(), top <= 60 else { return note }
        let missing = (1..<top).filter { !numbers.contains($0) }.map(String.init)
        guard !missing.isEmpty, missing.count <= 8 else { return note }
        let list = missing.count == 1 ? missing[0] : missing.dropLast().joined(separator: ", ") + " and " + missing.last!
        note += " · missing \(list)"
        return note
    }

    /// Every shown book in which each typed word is found: in the title, the author or the series.
    public func find(_ query: String) -> [Book] {
        let words = BookMatch.plain(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty else { return [] }
        return shown.filter { book in
            let hay = BookMatch.plain([book.title, book.author, book.series ?? ""].joined(separator: " "))
            return words.allSatisfy { hay.contains($0) }
        }
        .sorted { ($0.wish ? 1 : 0, BookMatch.titleKey($0.title)) < ($1.wish ? 1 : 0, BookMatch.titleKey($1.title)) }
    }
}

extension Date {
    /// The file keeps times to the second, so times are cut to the second before they are compared.
    var wholeSeconds: Date { Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down)) }
}

extension BookStore {
    public var name: String {
        switch self {
        case .kobo: return "Kobo"
        case .kindle: return "Kindle"
        case .apple: return "Apple Books"
        case .own: return "Own file"
        }
    }
}
