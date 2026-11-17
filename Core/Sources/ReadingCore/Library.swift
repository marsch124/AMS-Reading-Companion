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
                // But a title this store already brought (a list file without book numbers, read after the store's
                // own list) is the same copy again: nothing is added.
                if books[i].copies.contains(where: { $0.store == copy.store && $0.isAudio == copy.isAudio && $0.source != .hand }) {
                    let before = books[i]
                    fill(&books[i], from: item)
                    if books[i] != before { books[i].changed = now }
                    continue
                }
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
        books[i].gaveUp = false
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

    /// Tells whether a started book counts as being read now: opened in the 90 days before the latest reading,
    /// or set to Reading by the owner himself. A book he gave up never counts.
    private func currentReader() -> (Book) -> Bool {
        let latest = owned.compactMap(\.lastOpened).max() ?? Date()
        return { book in
            guard book.status == .reading, !book.gaveUp else { return false }
            if book.statusByHand { return true }
            guard let opened = book.lastOpened else { return true }   // the store gave no day: take its word
            return latest.timeIntervalSince(opened) <= 90 * 86_400
        }
    }

    public func shelves() -> [Shelf] {
        var out: [Shelf] = []
        let owned = self.owned
        let byTitle: (Book, Book) -> Bool = { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
        let recent: (Book, Book) -> Bool = { ($0.lastOpened ?? $0.changed) > ($1.lastOpened ?? $1.changed) }
        let current = currentReader()

        let reading = owned.filter(current).sorted(by: recent)
        if !reading.isEmpty { out.append(Shelf(id: "reading", title: "Reading now", colour: "purple", note: nil, books: reading)) }

        let unread = owned.filter { $0.status == .unread }
            .sorted { ($0.purchased ?? .distantPast, $1.title) > ($1.purchased ?? .distantPast, $0.title) }
        if !unread.isEmpty { out.append(Shelf(id: "unread", title: "Not read yet · \(unread.count)", colour: "red", note: nil, books: unread)) }

        var members: [String: [Book]] = [:]
        var names: [String: String] = [:]
        for book in owned {
            guard let name = book.series?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            let key = BookMatch.plain(name)
            members[key, default: []].append(book)
            names[key] = names[key] ?? name
        }
        for key in members.keys.sorted() {
            guard let books = members[key], books.count >= 2 else { continue }
            let sorted = books.sorted { ($0.seriesNumber ?? .infinity, $0.title) < ($1.seriesNumber ?? .infinity, $1.title) }
            out.append(Shelf(id: "series-\(key)", title: names[key] ?? key, colour: "green",
                             note: Self.seriesNote(sorted, info: series[key]), books: sorted))
        }

        // Started, then left alone: not opened in the 90 days before the latest reading.
        let aside = owned.filter { $0.status == .reading && !$0.gaveUp && !current($0) }.sorted(by: recent)
        if !aside.isEmpty { out.append(Shelf(id: "aside", title: "Set aside · \(aside.count)", colour: "brown", note: nil, books: aside)) }

        let lockFree = owned.filter(\.isLockFree).sorted(by: byTitle)
        if !lockFree.isEmpty { out.append(Shelf(id: "lockfree", title: "Lock-free · \(lockFree.count)", colour: "teal", note: nil, books: lockFree)) }

        let audio = owned.filter(\.isAudio).sorted(by: byTitle)
        if !audio.isEmpty { out.append(Shelf(id: "audio", title: "Audiobooks · \(audio.count)", colour: "amber", note: nil, books: audio)) }

        let twice = owned.filter(\.ownedTwice).sorted(by: byTitle)
        if !twice.isEmpty { out.append(Shelf(id: "twice", title: "Bought twice · \(twice.count)", colour: "pink", note: nil, books: twice)) }

        let finished = owned.filter { $0.status == .finished }.sorted(by: recent)
        if !finished.isEmpty { out.append(Shelf(id: "finished", title: "Finished · \(finished.count)", colour: "grey", note: nil, books: finished)) }

        let gaveUp = owned.filter { $0.gaveUp && $0.status == .reading }.sorted(by: byTitle)
        if !gaveUp.isEmpty { out.append(Shelf(id: "gaveup", title: "Gave up · \(gaveUp.count)", colour: "grey", note: nil, books: gaveUp)) }

        let wishes = shown.filter(\.wish).sorted { $0.added > $1.added }
        out.append(Shelf(id: "wish", title: wishes.isEmpty ? "Wish list" : "Wish list · \(wishes.count)", colour: "blue",
                         note: wishes.isEmpty ? "Nothing wished for yet." : nil, books: wishes))
        return out
    }

    public func shelf(_ id: String) -> Shelf? { shelves().first { $0.id == id } }

    /// "3 of 7 · missing 2, 4, 6 and 7" when a catalogue told how long the series is; otherwise "3 owned · missing 2 and 4",
    /// where gaps are only known below the highest number that is owned.
    static func seriesNote(_ books: [Book], info: SeriesInfo? = nil) -> String {
        let numbers = Set(books.compactMap(\.seriesNumber).filter { $0 >= 1 && $0 == $0.rounded() }.map { Int($0) })
        let top = numbers.max() ?? 0
        var note: String
        var last = top - 1
        if let total = info?.total, total >= max(top, books.count), total <= 200 {
            note = "\(books.count) of \(total)"
            last = total
        } else {
            note = "\(books.count) owned"
        }
        guard top >= 1, top <= 200, last >= 1 else { return note }
        let missing = (1...last).filter { !numbers.contains($0) }.map(String.init)
        guard !missing.isEmpty, missing.count <= 8 else { return note }
        let list = missing.count == 1 ? missing[0] : missing.dropLast().joined(separator: ", ") + " and " + missing.last!
        return note + " · missing \(list)"
    }

    /// The book that follows this one in its series: on the shelf, or known by name from a catalogue, or just a gap.
    public func nextInSeries(after book: Book) -> SeriesNext? {
        guard let name = book.series?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
              let number = book.seriesNumber, number >= 1, number == number.rounded() else { return nil }
        let key = BookMatch.plain(name)
        let next = Int(number) + 1
        let others = owned.filter { $0.id != book.id && BookMatch.plain($0.series ?? "") == key }
        if let have = others.first(where: { $0.seriesNumber == Double(next) }) {
            return SeriesNext(number: next, title: have.title, owned: have)
        }
        let info = series[key]
        if let volume = info?.volumes.first(where: { $0.number == Double(next) }) {
            return SeriesNext(number: next, title: volume.title, owned: nil)
        }
        if let total = info?.total { return next <= total ? SeriesNext(number: next, title: nil, owned: nil) : nil }
        // Nothing known about the series: a next book is only certain when a later one is on the shelf.
        return others.contains { ($0.seriesNumber ?? 0) > Double(next) } ? SeriesNext(number: next, title: nil, owned: nil) : nil
    }

    /// "What next?": the next book of a series whose earlier book is finished, then the newest purchase,
    /// then the books that have waited longest. Only books on the shelf that are not read yet.
    public func whatNext(limit: Int = 8) -> [ReadSuggestion] {
        var out: [ReadSuggestion] = []
        func add(_ book: Book, _ reason: String) {
            guard out.count < limit, !out.contains(where: { $0.book.id == book.id }) else { return }
            out.append(ReadSuggestion(book: book, reason: reason))
        }
        let owned = self.owned
        let done = owned.filter { $0.status == .finished && $0.series != nil }
            .sorted { ($0.lastOpened ?? $0.changed) > ($1.lastOpened ?? $1.changed) }
        for book in done {
            if let next = nextInSeries(after: book), let have = next.owned, have.status == .unread {
                add(have, "Next in \(book.series ?? "the series"), after “\(book.title)”")
            }
        }
        let unread = owned.filter { $0.status == .unread && $0.purchased != nil }
            .sorted { ($0.purchased ?? .distantPast) > ($1.purchased ?? .distantPast) }
        if let newest = unread.first { add(newest, "Your newest book") }
        let month = DateFormatter()
        month.locale = Locale(identifier: "en_GB")
        month.dateFormat = "MMMM yyyy"
        for book in unread.reversed() {
            guard let day = book.purchased else { continue }
            add(book, "Waiting since \(month.string(from: day))")
        }
        return out
    }

    // MARK: Stars, note, gave up, covers, series knowledge

    public mutating func setRating(_ stars: Int?, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].rating = stars.map { min(max($0, 1), 5) }
        books[i].changed = now.wholeSeconds
    }

    public mutating func setNote(_ text: String, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        books[i].note = line.isEmpty ? nil : line
        books[i].changed = now.wholeSeconds
    }

    /// Gave up: a started book the owner will not finish. It leaves "Set aside" and "Reading now".
    public mutating func setGaveUp(_ gaveUp: Bool, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].gaveUp = gaveUp
        if gaveUp { books[i].status = .reading }
        books[i].statusByHand = true
        books[i].changed = now.wholeSeconds
    }

    /// A cover picture found for a book that had none.
    public mutating func setCover(_ address: String, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }), books[i].coverURL == nil, !address.isEmpty else { return }
        books[i].coverURL = address
        books[i].changed = now.wholeSeconds
    }

    public func seriesInfo(for name: String) -> SeriesInfo? {
        series[BookMatch.plain(name.trimmingCharacters(in: .whitespaces))]
    }

    public mutating func setSeries(_ info: SeriesInfo, for name: String) {
        series[BookMatch.plain(name.trimmingCharacters(in: .whitespaces))] = info
    }

    /// The series on the shelf (2 or more books) with their names as written, for looking them up.
    public func seriesNames() -> [(name: String, author: String, title: String)] {
        var seen: [String: (String, String, String, Int)] = [:]
        for book in owned {
            guard let name = book.series?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            let key = BookMatch.plain(name)
            seen[key] = (name, seen[key]?.1 ?? book.author, seen[key]?.2 ?? book.title, (seen[key]?.3 ?? 0) + 1)
        }
        return seen.values.filter { $0.3 >= 2 }.map { (name: $0.0, author: $0.1, title: $0.2) }.sorted { $0.name < $1.name }
    }

    /// Every shown book in which each typed word is found: in the title, the author, the series or the owner's note.
    public func find(_ query: String) -> [Book] {
        let words = BookMatch.plain(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty else { return [] }
        return shown.filter { book in
            let hay = BookMatch.plain([book.title, book.author, book.series ?? "", book.note ?? ""].joined(separator: " "))
            return words.allSatisfy { hay.contains($0) }
        }
        .sorted { ($0.wish ? 1 : 0, BookMatch.titleKey($0.title)) < ($1.wish ? 1 : 0, BookMatch.titleKey($1.title)) }
    }
}

/// The book after this one in its series.
public struct SeriesNext: Equatable, Sendable {
    public var number: Int
    public var title: String?
    /// The book itself when it is on the shelf.
    public var owned: Book?
}

/// One answer to "What next?".
public struct ReadSuggestion: Identifiable, Equatable, Sendable {
    public var book: Book
    public var reason: String
    public var id: String { book.id }
}

/// How the books of one shelf are narrowed down and ordered on its page.
public struct ShelfFilter: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case all, read, listen }
    public enum Order: String, CaseIterable, Sendable { case shelf, title, author, newest }
    public var store: BookStore?
    public var kind: Kind
    public var order: Order

    public init(store: BookStore? = nil, kind: Kind = .all, order: Order = .shelf) {
        self.store = store; self.kind = kind; self.order = order
    }

    public var isPlain: Bool { store == nil && kind == .all && order == .shelf }

    public func apply(to books: [Book]) -> [Book] {
        var out = books
        if let store { out = out.filter { $0.copies.contains { $0.store == store } } }
        switch kind {
        case .all: break
        case .read: out = out.filter { $0.copies.isEmpty || $0.copies.contains { !$0.isAudio } }
        case .listen: out = out.filter(\.isAudio)
        }
        switch order {
        case .shelf: break
        case .title: out.sort { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
        case .author: out.sort { (BookMatch.authorKey($0.author), BookMatch.titleKey($0.title)) < (BookMatch.authorKey($1.author), BookMatch.titleKey($1.title)) }
        case .newest: out.sort { ($0.purchased ?? .distantPast) > ($1.purchased ?? .distantPast) }
        }
        return out
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
