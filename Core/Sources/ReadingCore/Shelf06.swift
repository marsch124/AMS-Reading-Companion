import Foundation

// The rules that came with version 0.6: tags, the big filter and filters kept as shelves, the choice and order
// of shelves, reading notes and their kinds, a book corrected by hand, what a book is about, the author's and
// the series' page, "Surprise me", and what changed with each store's list.

// MARK: - Data

/// One reading note the owner made on a book.
public struct ReadingNote: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var bookID: String
    public var text: String
    /// The id of its kind (see `NoteKind`).
    public var kind: String
    /// Where in the book, as the owner wrote it ("41", "chapter 3").
    public var page: String?
    public var made: Date
    public var changed: Date
    /// Thrown away. Kept as a marker so another device does not bring it back.
    public var removed: Bool

    public init(id: String, bookID: String, text: String, kind: String, page: String? = nil,
                made: Date = Date(), changed: Date = Date(), removed: Bool = false) {
        self.id = id; self.bookID = bookID; self.text = text; self.kind = kind; self.page = page
        self.made = made; self.changed = changed; self.removed = removed
    }

    enum CodingKeys: String, CodingKey { case id, bookID, text, kind, page, made, changed, removed }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bookID = try c.decode(String.self, forKey: .bookID)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        kind = (try? c.decode(String.self, forKey: .kind)) ?? ""
        page = try? c.decodeIfPresent(String.self, forKey: .page)
        made = (try? c.decode(Date.self, forKey: .made)) ?? Date(timeIntervalSince1970: 0)
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? Date(timeIntervalSince1970: 0)
        removed = (try? c.decode(Bool.self, forKey: .removed)) ?? false
    }
}

/// A kind of note: the start set, and the owner's own.
public struct NoteKind: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// A colour name of the app's Theme.
    public var colour: String
    public init(id: String, name: String, colour: String) { self.id = id; self.name = name; self.colour = colour }

    /// What every shelf starts with.
    public static let start: [NoteKind] = [
        NoteKind(id: "quote", name: "Quote", colour: "purple"),
        NoteKind(id: "thought", name: "Thought", colour: "teal"),
        NoteKind(id: "todo", name: "To do", colour: "red"),
        NoteKind(id: "word", name: "Word to look up", colour: "blue"),
    ]
    /// The colours a new kind of the owner's gets, in turn.
    static let ownColours = ["green", "pink", "indigo", "amber", "brown"]
    /// A note whose kind was removed stands under this one.
    public static let other = NoteKind(id: "", name: "Other", colour: "grey")
}

/// Where a book stands, for the filter: one of these for every shown book.
public enum ShelfState: String, Codable, CaseIterable, Sendable {
    case unread, reading, aside, finished, gaveUp, wish

    public var name: String {
        switch self {
        case .unread: return "Not read"
        case .reading: return "Reading"
        case .aside: return "Set aside"
        case .finished: return "Finished"
        case .gaveUp: return "Gave up"
        case .wish: return "Wish"
        }
    }
}

/// The big filter. Inside one group a book needs ONE of the choices; across groups it needs ALL groups.
/// Nothing chosen in a group = that group does not narrow.
public struct BookFilter: Codable, Hashable, Sendable {
    public var stores: Set<BookStore> = []
    public var kinds: Set<BookKind> = []
    /// Two-letter codes; "" = language not known.
    public var languages: Set<String> = []
    public var states: Set<ShelfState> = []
    /// nil = any; 0 = no stars yet; 1...5 = that many or more.
    public var stars: Int?
    /// Bought in one of these years …
    public var boughtYears: Set<Int> = []
    /// … or before this year ("Earlier").
    public var boughtBefore: Int?
    public var finishedYears: Set<Int> = []
    public var lockFree = false
    /// Tags, written plainly (see `LibraryData.tagKey`).
    public var tags: Set<String> = []

    public init() {}

    /// Nothing chosen at all.
    public var isEmpty: Bool { self == BookFilter() }

    /// How many choices are made.
    public var choices: Int {
        stores.count + kinds.count + languages.count + states.count + (stars == nil ? 0 : 1) + boughtYears.count
            + (boughtBefore == nil ? 0 : 1) + finishedYears.count + (lockFree ? 1 : 0) + tags.count
    }

    enum CodingKeys: String, CodingKey {
        case stores, kinds, languages, states, stars, boughtYears, boughtBefore, finishedYears, lockFree, tags
    }

    /// Tolerant: a choice a newer version knows and this one does not is left out.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func words(_ key: CodingKeys) -> [String] { (try? c.decode([String].self, forKey: key)) ?? [] }
        stores = Set(words(.stores).compactMap(BookStore.init(rawValue:)))
        kinds = Set(words(.kinds).compactMap(BookKind.init(rawValue:)))
        languages = Set(words(.languages))
        states = Set(words(.states).compactMap(ShelfState.init(rawValue:)))
        stars = try? c.decodeIfPresent(Int.self, forKey: .stars)
        boughtYears = Set((try? c.decode([Int].self, forKey: .boughtYears)) ?? [])
        boughtBefore = try? c.decodeIfPresent(Int.self, forKey: .boughtBefore)
        finishedYears = Set((try? c.decode([Int].self, forKey: .finishedYears)) ?? [])
        lockFree = (try? c.decode(Bool.self, forKey: .lockFree)) ?? false
        tags = Set(words(.tags))
    }

    /// Written in a fixed order, so the same filter is always the same text in the file.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stores.map(\.rawValue).sorted(), forKey: .stores)
        try c.encode(kinds.map(\.rawValue).sorted(), forKey: .kinds)
        try c.encode(languages.sorted(), forKey: .languages)
        try c.encode(states.map(\.rawValue).sorted(), forKey: .states)
        try c.encodeIfPresent(stars, forKey: .stars)
        try c.encode(boughtYears.sorted(), forKey: .boughtYears)
        try c.encodeIfPresent(boughtBefore, forKey: .boughtBefore)
        try c.encode(finishedYears.sorted(), forKey: .finishedYears)
        try c.encode(lockFree, forKey: .lockFree)
        try c.encode(tags.sorted(), forKey: .tags)
    }

    public static func kindName(_ kind: BookKind) -> String {
        switch kind {
        case .ebook: return "To read"
        case .audiobook: return "To listen"
        case .pdf: return "PDF"
        }
    }

    public static func starsName(_ stars: Int) -> String {
        switch stars {
        case 0: return "No stars yet"
        case 5: return "5 stars"
        default: return "\(stars) stars or more"
        }
    }

    /// The filter in words, group by group: "Kobo · To read · Svenska · Not read". Empty for an empty filter.
    public var words: String {
        var out: [String] = []
        let storeOrder: [BookStore] = [.kobo, .kindle, .apple, .own]
        out += storeOrder.filter(stores.contains).map(\.name)
        let kindOrder: [BookKind] = [.ebook, .audiobook, .pdf]
        out += kindOrder.filter(kinds.contains).map(Self.kindName)
        out += languages.sorted().map { $0.isEmpty ? "Language not known" : BookLanguage.name($0) }
        out += ShelfState.allCases.filter(states.contains).map(\.name)
        if let stars { out.append(Self.starsName(stars)) }
        var bought = boughtYears.sorted(by: >).map(String.init)
        if let boughtBefore { bought.append("before \(boughtBefore)") }
        if !bought.isEmpty { out.append("Bought " + bought.joined(separator: ", ")) }
        if !finishedYears.isEmpty { out.append("Finished " + finishedYears.sorted(by: >).map(String.init).joined(separator: ", ")) }
        if lockFree { out.append("Lock-free") }
        out += tags.sorted()
        return out.joined(separator: " · ")
    }
}

/// A filter the owner kept as a shelf of his own.
public struct SavedFilter: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var filter: BookFilter
    public var changed: Date
    public var removed: Bool

    public init(id: String, name: String, filter: BookFilter, changed: Date = Date(), removed: Bool = false) {
        self.id = id; self.name = name; self.filter = filter; self.changed = changed; self.removed = removed
    }

    enum CodingKeys: String, CodingKey { case id, name, filter, changed, removed }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Filter"
        filter = (try? c.decode(BookFilter.self, forKey: .filter)) ?? BookFilter()
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? Date(timeIntervalSince1970: 0)
        removed = (try? c.decode(Bool.self, forKey: .removed)) ?? false
    }
}

/// What one read of a store's list brought and took away.
public struct ChangeEntry: Codable, Equatable, Sendable, Identifiable {
    /// How many reads are remembered.
    public static let kept = 40
    /// How many titles one read lists by name.
    public static let named = 40

    public var id: String
    public var date: Date
    /// "apple", "kobo", "kindle" or "file".
    public var store: String
    /// The titles that came, by name (at most `named`), and how many came in all.
    public var came: [String]
    public var cameCount: Int
    public var left: [String]
    public var leftCount: Int

    public init(date: Date, store: String, came: [String], left: [String]) {
        self.id = "\(store)-\(Int(date.timeIntervalSince1970))"
        self.date = date; self.store = store
        self.came = Array(came.prefix(Self.named)); self.cameCount = came.count
        self.left = Array(left.prefix(Self.named)); self.leftCount = left.count
    }

    public var storeName: String {
        switch store {
        case "apple": return "Apple Books"
        case "kobo": return "Kobo"
        case "kindle": return "Kindle"
        default: return "Your own files"
        }
    }
}

/// One part of a series on the series' page.
public struct SeriesPart: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case owned, wish, missing }
    public var number: Int?
    /// The part's title: the book's own, else what a catalogue calls it, else nil.
    public var title: String?
    /// The book on the shelf or on the wish list. nil for a missing part.
    public var book: Book?
    public var kind: Kind
    public var id: String { book?.id ?? "part-\(number ?? 0)" }
}

/// One line of "Choose your shelves".
public struct ShelfChoice: Identifiable, Equatable, Sendable {
    /// What stands in the order: a shelf's id, or "series" for all series shelves together.
    public var key: String
    public var name: String
    public var hidden: Bool
    /// How many books (for "series": how many series shelves) it has now.
    public var count: Int
    public var id: String { key }
}

// MARK: - Rules

extension LibraryData {

    // MARK: Tags

    /// A tag written plainly, to tell two spellings of the same tag apart from two tags.
    public static func tagKey(_ tag: String) -> String {
        BookMatch.plain(tag).split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).joined(separator: " ")
    }

    /// Tags as they are kept: trimmed, at most 30 letters, each once (by its plain form), in the order given.
    public static func cleanTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { raw in
            let tag = String(raw.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).joined(separator: " ").prefix(30))
            let key = tagKey(tag)
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return tag
        }
    }

    public mutating func setTags(_ tags: [String], of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        let clean = Self.cleanTags(tags)
        guard clean != books[i].tags else { return }
        books[i].tags = clean
        books[i].changed = now.wholeSeconds
    }

    /// Every tag in use on a shown book, the most used first, written as on the book that uses it first.
    public func allTags() -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        var names: [String: String] = [:]
        for book in shown {
            for tag in book.tags {
                let key = Self.tagKey(tag)
                counts[key, default: 0] += 1
                names[key] = names[key] ?? tag
            }
        }
        return counts.map { (tag: names[$0.key] ?? $0.key, count: $0.value) }
            .sorted { ($1.count, Self.tagKey($0.tag)) < ($0.count, Self.tagKey($1.tag)) }
    }

    // MARK: The big filter

    /// Where a book stands: a wish, not read, reading now, set aside, given up or finished.
    public func state(of book: Book) -> ShelfState { state(of: book, current: currentReader()) }

    private func state(of book: Book, current: (Book) -> Bool) -> ShelfState {
        if book.copies.isEmpty { return .wish }
        switch book.status {
        case .unread: return .unread
        case .finished: return .finished
        case .reading: return book.gaveUp ? .gaveUp : (current(book) ? .reading : .aside)
        }
    }

    /// The books that fit a filter, by title. Wishes only come along when "Wish" is chosen under Status.
    public func books(matching filter: BookFilter, calendar: Calendar = .current) -> [Book] {
        let current = currentReader()
        let pool = filter.states.contains(.wish) ? shown.filter { !$0.copies.isEmpty || $0.wish } : owned
        return pool.filter { book in
            if !filter.states.isEmpty, !filter.states.contains(state(of: book, current: current)) { return false }
            if !filter.stores.isEmpty, !book.copies.contains(where: { filter.stores.contains($0.store) }) { return false }
            if !filter.kinds.isEmpty, !book.copies.contains(where: { filter.kinds.contains($0.kind) }) { return false }
            if !filter.languages.isEmpty, !filter.languages.contains(book.language ?? "") { return false }
            if let stars = filter.stars {
                if stars <= 0 { if book.rating != nil { return false } }
                else if (book.rating ?? 0) < stars { return false }
            }
            if !filter.boughtYears.isEmpty || filter.boughtBefore != nil {
                guard let day = book.purchased else { return false }
                let year = calendar.component(.year, from: day)
                let before = filter.boughtBefore.map { year < $0 } ?? false
                if !filter.boughtYears.contains(year), !before { return false }
            }
            if !filter.finishedYears.isEmpty {
                guard let day = book.finishedDay, filter.finishedYears.contains(calendar.component(.year, from: day)) else { return false }
            }
            if filter.lockFree, !book.isLockFree { return false }
            if !filter.tags.isEmpty, !book.tags.contains(where: { filter.tags.contains(Self.tagKey($0)) }) { return false }
            return true
        }
        .sorted { (BookMatch.titleKey($0.title), $0.id) < (BookMatch.titleKey($1.title), $1.id) }
    }

    /// The years in which owned books were bought, the latest first.
    public func boughtYears(calendar: Calendar = .current) -> [Int] {
        Set(owned.compactMap(\.purchased).map { calendar.component(.year, from: $0) }).sorted(by: >)
    }

    /// The years in which owned books were finished, the latest first.
    public func finishedYears(calendar: Calendar = .current) -> [Int] {
        Set(owned.compactMap(\.finishedDay).map { calendar.component(.year, from: $0) }).sorted(by: >)
    }

    // MARK: A filter kept as a shelf

    /// Keeps a filter as a shelf of the owner's own. An empty filter or an empty name keeps nothing.
    @discardableResult
    public mutating func keepFilter(_ filter: BookFilter, name: String, now: Date = Date(),
                                    newID: String = UUID().uuidString) -> SavedFilter? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filter.isEmpty, !name.isEmpty else { return nil }
        let kept = SavedFilter(id: newID, name: String(name.prefix(40)), filter: filter, changed: now.wholeSeconds)
        savedFilters.append(kept)
        return kept
    }

    /// Changes a kept filter: its name, its choices, or both.
    public mutating func changeKeptFilter(_ id: String, name: String? = nil, filter: BookFilter? = nil, now: Date = Date()) {
        guard let i = savedFilters.firstIndex(where: { $0.id == id && !$0.removed }) else { return }
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { savedFilters[i].name = String(name.prefix(40)) }
        if let filter, !filter.isEmpty { savedFilters[i].filter = filter }
        savedFilters[i].changed = now.wholeSeconds
    }

    public mutating func removeKeptFilter(_ id: String, now: Date = Date()) {
        guard let i = savedFilters.firstIndex(where: { $0.id == id && !$0.removed }) else { return }
        savedFilters[i].removed = true
        savedFilters[i].changed = now.wholeSeconds
    }

    /// The kept filter behind a shelf id ("saved-…"), if that is what the shelf is.
    public func keptFilter(shelfID: String) -> SavedFilter? {
        guard shelfID.hasPrefix("saved-") else { return nil }
        let id = String(shelfID.dropFirst("saved-".count))
        return savedFilters.first { $0.id == id && !$0.removed }
    }

    // MARK: Choose your shelves

    /// What stands for a shelf in the owner's order: its id, or "series" for every series shelf.
    public static func orderKey(_ shelfID: String) -> String { shelfID.hasPrefix("series-") ? "series" : shelfID }

    private static let fixedShelves: [(key: String, name: String)] = [
        ("reading", "Reading now"), ("upnext", "Up next"), ("unread", "Not read yet"), ("series", "Series"),
        ("aside", "Set aside"), ("lockfree", "Lock-free"), ("audio", "Audiobooks"), ("twice", "Bought twice"),
        ("finished", "Finished"), ("gaveup", "Gave up"), ("wish", "Wish list"),
    ]

    /// Every key a shelf can have, in the order the owner chose: his order first; a key his order does not know
    /// (a filter kept later) goes to the front when it is his own shelf, else to the end.
    private func orderedKeys() -> [String] {
        let saved = savedFilters.filter { !$0.removed }.map { "saved-\($0.id)" }
        let builtIn = ["reading", "upnext"] + saved + Self.fixedShelves.map(\.key).filter { $0 != "reading" && $0 != "upnext" }
        guard !shelfOrder.isEmpty else { return builtIn }
        let known = Set(builtIn)
        var seen = Set<String>()
        let mine = shelfOrder.filter { known.contains($0) && seen.insert($0).inserted }
        let newSaved = saved.filter { !seen.contains($0) }
        let rest = builtIn.filter { !seen.contains($0) && !$0.hasPrefix("saved-") }
        return newSaved + mine + rest
    }

    /// The shelves of the main screen: without the hidden ones, in the owner's order.
    public func mainShelves() -> [Shelf] {
        let all = shelves()
        let hidden = Set(hiddenShelves)
        var out: [Shelf] = []
        for key in orderedKeys() where !hidden.contains(key) {
            out += all.filter { Self.orderKey($0.id) == key }
        }
        return out
    }

    /// The lines of "Choose your shelves", in the owner's order.
    public func shelfChoices() -> [ShelfChoice] {
        let all = shelves()
        let hidden = Set(hiddenShelves)
        return orderedKeys().map { key in
            let mine = all.filter { Self.orderKey($0.id) == key }
            let name: String
            if let kept = keptFilter(shelfID: key) { name = kept.name }
            else { name = Self.fixedShelves.first { $0.key == key }?.name ?? key }
            let count = key == "series" ? mine.count : (mine.first?.books.count ?? 0)
            return ShelfChoice(key: key, name: name, hidden: hidden.contains(key), count: count)
        }
    }

    public mutating func setShelves(order: [String], hidden: [String], now: Date = Date()) {
        guard order != shelfOrder || hidden != hiddenShelves else { return }
        shelfOrder = order
        hiddenShelves = hidden
        shelvesChanged = now.wholeSeconds
    }

    // MARK: Surprise me

    /// A book picked by chance among the owned books that are not started. Not the one shown last, when there is another.
    public func surprise<G: RandomNumberGenerator>(not last: String? = nil, using generator: inout G) -> Book? {
        let pool = owned.filter { $0.status == .unread }
        let others = pool.filter { $0.id != last }
        return (others.isEmpty ? pool : others).randomElement(using: &generator)
    }

    public func surprise(not last: String? = nil) -> Book? {
        var generator = SystemRandomNumberGenerator()
        return surprise(not: last, using: &generator)
    }

    // MARK: Correct a book, what it is about

    /// The owner corrects a book's details. From then on a store's list no longer changes them.
    /// An empty title keeps the title; an empty series takes the book out of its series.
    public mutating func correct(_ id: String, title: String, author: String, series: String?, number: Double?, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let series = series?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if books[i].storeDetails == nil {
            books[i].storeDetails = BookDetails(title: books[i].title, author: books[i].author,
                                                series: books[i].series, seriesNumber: books[i].seriesNumber)
        }
        if !title.isEmpty { books[i].title = title }
        books[i].author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        books[i].series = series.isEmpty ? nil : series
        books[i].seriesNumber = series.isEmpty ? nil : number
        books[i].detailsByHand = true
        books[i].changed = now.wholeSeconds
    }

    /// Takes the owner's correction away: title, author and series are at once what they were before it,
    /// and a store's list may change them again.
    public mutating func uncorrect(_ id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }), books[i].detailsByHand else { return }
        if let before = books[i].storeDetails {
            books[i].title = before.title
            books[i].author = before.author
            books[i].series = before.series
            books[i].seriesNumber = before.seriesNumber
        }
        books[i].storeDetails = nil
        books[i].detailsByHand = false
        books[i].changed = now.wholeSeconds
    }

    /// What a catalogue said the book is about; nil = it was asked and knew nothing. Not the owner's doing,
    /// so the book's `changed` stays (`merged` carries the words across).
    public mutating func setAbout(_ text: String?, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        if let text, !text.isEmpty { books[i].about = text }
        else { books[i].aboutChecked = now.wholeSeconds }
    }

    /// Whether a catalogue should be asked what the book is about: nothing known, and not asked in the last 30 days.
    public func shouldAskAbout(_ book: Book, now: Date = Date()) -> Bool {
        guard book.about == nil else { return false }
        guard let asked = book.aboutChecked else { return true }
        return now.timeIntervalSince(asked) > 30 * 86_400
    }

    // MARK: The author's page

    /// Every shown book of this author (told by the first author's last name), owned and wished:
    /// series first in their order, then by title; wishes last.
    public func books(by author: String) -> [Book] {
        let key = BookMatch.authorKey(author)
        guard !key.isEmpty else { return [] }
        // Two authors with the same last name (a father and a son) are told apart by the first letter of the
        // first name, where both are written with one.
        let initial = Self.firstInitial(author)
        return shown.filter { book in
            guard BookMatch.authorKey(book.author) == key else { return false }
            let other = Self.firstInitial(book.author)
            return initial == nil || other == nil || initial == other
        }.sorted {
            ($0.wish ? 1 : 0, $0.series == nil ? 1 : 0, BookMatch.plain($0.series ?? ""), $0.seriesNumber ?? .infinity, BookMatch.titleKey($0.title))
                < ($1.wish ? 1 : 0, $1.series == nil ? 1 : 0, BookMatch.plain($1.series ?? ""), $1.seriesNumber ?? .infinity, BookMatch.titleKey($1.title))
        }
    }

    /// The first letter of the first author's first name: "Frank Herbert" and "Herbert, Frank" give "f";
    /// a name written as one word gives nil.
    static func firstInitial(_ author: String) -> Character? {
        var a = BookMatch.plain(author)
        for mark in [";", "&", " and ", " och ", " und "] {
            if let r = a.range(of: mark) { a = String(a[..<r.lowerBound]) }
        }
        let parts = a.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.count >= 2, !parts[0].contains(" ") { return parts[1].first(where: \.isLetter) }
        let words = (parts.first ?? "").split(separator: " ")
        guard words.count >= 2 else { return nil }
        return words[0].first(where: \.isLetter)
    }

    // MARK: The series' page

    private func whole(_ number: Double?) -> Int? {
        guard let number, number >= 1, number <= 200, number == number.rounded() else { return nil }
        return Int(number)
    }

    /// Every part of a series in order: owned, wished or missing. The length is the catalogue's (or the owner's)
    /// total when known, else the highest number on the shelf. Books without a whole number come last.
    public func seriesParts(_ name: String) -> [SeriesPart] {
        let key = BookMatch.plain(name.trimmingCharacters(in: .whitespaces))
        guard !key.isEmpty else { return [] }
        let mine = shown.filter { BookMatch.plain(($0.series ?? "").trimmingCharacters(in: .whitespaces)) == key }
            .sorted { ($0.wish ? 1 : 0, $0.seriesNumber ?? .infinity, $0.title) < ($1.wish ? 1 : 0, $1.seriesNumber ?? .infinity, $1.title) }
        let info = series[key]
        var slots: [Int: Book] = [:]
        var loose: [Book] = []
        for book in mine {
            if let n = whole(book.seriesNumber), slots[n] == nil { slots[n] = book } else { loose.append(book) }
        }
        let volumes = info?.volumes ?? []
        let top = min(200, max(info?.total ?? 0, slots.keys.max() ?? 0, volumes.compactMap { whole($0.number) }.max() ?? 0))
        var out: [SeriesPart] = []
        if top >= 1 {
            for n in 1...top {
                let known = volumes.first { $0.number == Double(n) }?.title
                if let book = slots[n] {
                    out.append(SeriesPart(number: n, title: book.title, book: book, kind: book.copies.isEmpty ? .wish : .owned))
                } else {
                    out.append(SeriesPart(number: n, title: known, book: nil, kind: .missing))
                }
            }
        }
        out += loose.map { SeriesPart(number: whole($0.seriesNumber), title: $0.title, book: $0, kind: $0.copies.isEmpty ? .wish : .owned) }
        return out
    }

    /// The series' name as the shelf writes it, and its author (the one most of its books have).
    public func seriesHead(_ name: String) -> (name: String, author: String) {
        let key = BookMatch.plain(name.trimmingCharacters(in: .whitespaces))
        let mine = shown.filter { BookMatch.plain(($0.series ?? "").trimmingCharacters(in: .whitespaces)) == key }
        var counts: [String: Int] = [:]
        for book in mine where !book.author.isEmpty { counts[book.author, default: 0] += 1 }
        let author = counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? ""
        return (mine.first?.series?.trimmingCharacters(in: .whitespaces) ?? name, author)
    }

    /// Puts a missing part of a series on the wish list, in its place in the series.
    /// A part nobody knows the title of is wished as "<Series> 3".
    @discardableResult
    public mutating func wishSeriesPart(series name: String, number: Int, title: String?, now: Date = Date(),
                                        newID: String = UUID().uuidString) -> Book? {
        let head = seriesHead(name)
        let title = title?.trimmingCharacters(in: .whitespaces) ?? ""
        guard let book = add(title: title.isEmpty ? "\(head.name) \(number)" : title, author: head.author, store: nil, now: now, newID: newID),
              let i = books.firstIndex(where: { $0.id == book.id }) else { return nil }
        // Only a wish gets its place in the series from here; a book already owned under that title keeps its own.
        if books[i].wish, books[i].copies.isEmpty {
            books[i].series = head.name
            books[i].seriesNumber = Double(number)
            books[i].changed = now.wholeSeconds
        }
        return books[i]
    }

    // MARK: Progress on covers

    /// How far a book is read, for the thin bar on its cover: only for a started book, between 1 % and 99 %.
    public static func coverProgress(_ book: Book) -> Double? {
        guard book.status == .reading, !book.gaveUp, let p = book.progress, p >= 0.01, p < 0.995 else { return nil }
        return p
    }

    // MARK: What changed

    /// Remembers what a read of a store's list brought and took away. A read that changed no title is not
    /// remembered, nor is the very first read of a store (`first`), which brings everything.
    public mutating func noteChange(_ summary: ImportSummary, store: String, first: Bool, now: Date = Date()) {
        guard !first, !summary.came.isEmpty || !summary.left.isEmpty else { return }
        changes.insert(ChangeEntry(date: now.wholeSeconds, store: store, came: summary.came, left: summary.left), at: 0)
        if changes.count > ChangeEntry.kept { changes = Array(changes.prefix(ChangeEntry.kept)) }
    }

    // MARK: Reading notes

    /// The notes that show: not thrown away, on a book that is still shown. The newest first.
    public var shownNotes: [ReadingNote] {
        let ids = Set(shown.map(\.id))
        return notes.filter { !$0.removed && ids.contains($0.bookID) }.sorted { ($0.made, $0.id) > ($1.made, $1.id) }
    }

    public func notes(of bookID: String) -> [ReadingNote] { shownNotes.filter { $0.bookID == bookID } }

    public func note(_ id: String) -> ReadingNote? { notes.first { $0.id == id && !$0.removed } }

    /// A note's kind; a kind that was removed gives "Other".
    public func kind(_ id: String) -> NoteKind { noteKinds.first { $0.id == id } ?? .other }

    /// The kinds to choose from, and "Other" after them when a shown note stands under a removed kind.
    public func kindsInUse() -> [(kind: NoteKind, count: Int)] {
        let all = shownNotes
        var out = noteKinds.map { kind in (kind: kind, count: all.filter { $0.kind == kind.id }.count) }
        let known = Set(noteKinds.map(\.id))
        let other = all.filter { !known.contains($0.kind) }.count
        if other > 0 { out.append((kind: .other, count: other)) }
        return out
    }

    /// Writes a new note on a book. Empty words write nothing.
    @discardableResult
    public mutating func addNote(bookID: String, text: String, kind: String, page: String? = nil, now: Date = Date(),
                                 newID: String = UUID().uuidString) -> ReadingNote? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, book(bookID) != nil else { return nil }
        let page = page?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = ReadingNote(id: newID, bookID: bookID, text: text, kind: kind, page: page.isEmpty ? nil : page,
                               made: now.wholeSeconds, changed: now.wholeSeconds)
        notes.append(note)
        return note
    }

    /// Changes a note's words, kind, page or book. Empty words leave the note as it is.
    public mutating func changeNote(_ id: String, text: String, kind: String, page: String?, bookID: String? = nil, now: Date = Date()) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let i = notes.firstIndex(where: { $0.id == id && !$0.removed }) else { return }
        let page = page?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        notes[i].text = text
        notes[i].kind = kind
        notes[i].page = page.isEmpty ? nil : page
        if let bookID, book(bookID) != nil { notes[i].bookID = bookID }
        notes[i].changed = now.wholeSeconds
    }

    public mutating func removeNote(_ id: String, now: Date = Date()) {
        guard let i = notes.firstIndex(where: { $0.id == id && !$0.removed }) else { return }
        notes[i].removed = true
        notes[i].changed = now.wholeSeconds
    }

    /// The book a new note is most likely for: the one being read now that was opened last.
    public var noteBook: Book? { shelf("reading")?.books.first }

    // MARK: Kinds of notes

    /// Adds a kind of the owner's own. A name that is empty or already there adds nothing.
    @discardableResult
    public mutating func addKind(_ name: String, now: Date = Date(), newID: String = UUID().uuidString) -> NoteKind? {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !name.isEmpty, !noteKinds.contains(where: { BookMatch.plain($0.name) == BookMatch.plain(name) }) else { return nil }
        let used = Set(noteKinds.map(\.colour))
        let colour = NoteKind.ownColours.first { !used.contains($0) } ?? NoteKind.ownColours[noteKinds.count % NoteKind.ownColours.count]
        let kind = NoteKind(id: newID, name: name, colour: colour)
        noteKinds.append(kind)
        noteKindsChanged = now.wholeSeconds
        return kind
    }

    public mutating func renameKind(_ id: String, to name: String, now: Date = Date()) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !name.isEmpty, let i = noteKinds.firstIndex(where: { $0.id == id }), noteKinds[i].name != name else { return }
        noteKinds[i].name = name
        noteKindsChanged = now.wholeSeconds
    }

    /// Takes a kind away. Its notes stay and stand under "Other". The last kind stays: a note needs one.
    public mutating func removeKind(_ id: String, now: Date = Date()) {
        guard noteKinds.count > 1, noteKinds.contains(where: { $0.id == id }) else { return }
        noteKinds.removeAll { $0.id == id }
        noteKindsChanged = now.wholeSeconds
    }

    // MARK: Sending notes

    private static func noteDay(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    /// One note as words to send to another app: the note, then the book it is from.
    /// A quote stands in quotation marks.
    public func noteText(_ note: ReadingNote) -> String {
        let book = self.book(note.bookID)
        var from = "“\(book?.title ?? "A book")”"
        if let author = book?.author, !author.isEmpty { from += " by \(author)" }
        if let page = note.page { from += ", \(Self.pageWords(page))" }
        let kind = self.kind(note.kind)
        let body = note.kind == "quote" ? "“\(Self.bare(note.text))”" : note.text
        return "\(body)\n\n— \(kind.name), \(from)"
    }

    /// A quote without quotation marks the owner typed around it himself.
    static func bare(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”„«»").union(.whitespacesAndNewlines))
    }

    /// "page 41" for a bare number, else the owner's own words ("chapter 3").
    static func pageWords(_ page: String) -> String {
        page.allSatisfy(\.isNumber) ? "page \(page)" : page
    }

    /// All notes of one book as one tidy page (plain words with Markdown headings, which a notes app shows
    /// as headings and any other app shows as they are): kind by kind, the oldest note first.
    public func notesPage(of bookID: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let book = book(bookID) else { return "" }
        let mine = notes(of: bookID).reversed()
        var lines = ["# Notes on “\(book.title)”"]
        var head: [String] = []
        if !book.author.isEmpty { head.append(book.author) }
        head.append(mine.count == 1 ? "1 note" : "\(mine.count) notes")
        head.append(Self.noteDay(now, calendar: calendar))
        lines.append(head.joined(separator: " · "))
        for (kind, _) in kindsInUse() {
            let known = Set(noteKinds.map(\.id))
            let these = mine.filter { kind.id.isEmpty ? !known.contains($0.kind) : $0.kind == kind.id }
            guard !these.isEmpty else { continue }
            lines.append("")
            lines.append("## \(kind.name)")
            for note in these {
                let place = note.page.map { " (\(Self.pageWords($0)))" } ?? ""
                let text = note.text.replacingOccurrences(of: "\n", with: " ")
                lines.append(kind.id == "quote" ? "> “\(Self.bare(text))”\(place)" : "- \(text)\(place)")
                if kind.id == "quote" { lines.append("") }
            }
            if lines.last == "" { lines.removeLast() }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
