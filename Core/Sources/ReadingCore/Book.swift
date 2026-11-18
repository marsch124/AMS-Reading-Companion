import Foundation

public enum ReadStatus: String, Codable, Sendable, CaseIterable { case unread, reading, finished }

/// Where a copy on the shelf came from. A store's reader may only take away what it brought itself.
public enum CopySource: String, Codable, Sendable { case apple, kindle, kobo, file, hand }

/// One store's copy of a book.
public struct BookCopy: Codable, Equatable, Sendable, Identifiable {
    public var store: BookStore
    public var storeID: String
    public var kind: BookKind
    public var lockFree: Bool
    public var filePath: String?
    public var purchased: Date?
    public var source: CopySource

    public var id: String { "\(store.rawValue):\(storeID)" }
    public var isAudio: Bool { kind == .audiobook }

    public init(store: BookStore, storeID: String, kind: BookKind = .ebook, lockFree: Bool = false,
                filePath: String? = nil, purchased: Date? = nil, source: CopySource = .hand) {
        self.store = store; self.storeID = storeID; self.kind = kind; self.lockFree = lockFree
        self.filePath = filePath; self.purchased = purchased; self.source = source
    }

    enum CodingKeys: String, CodingKey { case store, storeID, kind, lockFree, filePath, purchased, source }

    /// Tolerant: a field a newer or older version does not know gets its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        store = try c.decode(BookStore.self, forKey: .store)
        storeID = try c.decode(String.self, forKey: .storeID)
        kind = (try? c.decode(BookKind.self, forKey: .kind)) ?? .ebook
        lockFree = (try? c.decode(Bool.self, forKey: .lockFree)) ?? false
        filePath = try? c.decodeIfPresent(String.self, forKey: .filePath)
        purchased = try? c.decodeIfPresent(Date.self, forKey: .purchased)
        source = (try? c.decode(CopySource.self, forKey: .source)) ?? .hand
    }
}

/// One book on the shelf: one title, however many stores hold it. A wish has no copies.
public struct Book: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var author: String
    public var coverURL: String?
    public var series: String?
    public var seriesNumber: Double?
    public var copies: [BookCopy]
    public var status: ReadStatus
    /// Once the owner sets the status himself, a store's reading progress no longer changes it.
    public var statusByHand: Bool
    public var wish: Bool
    /// Taken off the shelf by hand. Kept as a marker so another device or a later read does not bring it back.
    public var removed: Bool
    public var progress: Double?
    public var lastOpened: Date?
    public var added: Date
    /// When this book last changed. Between two devices the newer change wins.
    public var changed: Date
    /// The owner's own stars, 1 to 5.
    public var rating: Int?
    /// The owner's own line about the book.
    public var note: String?
    /// Started and put away for good: it leaves "Set aside" and stands under "Gave up".
    public var gaveUp: Bool
    /// The language the book is written in, as a two-letter code ("sv", "de", "en"). nil = not known.
    public var language: String?
    /// Once the owner sets the language himself, a store or a guess no longer changes it.
    public var languageByHand: Bool
    /// The day the book was finished. nil on a book finished before version 0.5 (see `finishedDay`).
    public var finished: Date?
    /// The owner's own tags, as he wrote them.
    public var tags: [String]
    /// What the book is about, in the publisher's words (from a catalogue).
    public var about: String?
    /// When a catalogue was last asked what the book is about and knew nothing.
    public var aboutChecked: Date?
    /// The owner corrected title, author or series himself: a store's list no longer changes them.
    public var detailsByHand: Bool
    /// What title, author and series were before the owner's first correction: the store's own words.
    /// By them the book is still told to be the same when another store lists it, and they come back on "uncorrect".
    public var storeDetails: BookDetails?

    public init(id: String, title: String, author: String = "", coverURL: String? = nil, series: String? = nil,
                seriesNumber: Double? = nil, copies: [BookCopy] = [], status: ReadStatus = .unread,
                statusByHand: Bool = false, wish: Bool = false, removed: Bool = false, progress: Double? = nil,
                lastOpened: Date? = nil, added: Date = Date(), changed: Date = Date(),
                rating: Int? = nil, note: String? = nil, gaveUp: Bool = false,
                language: String? = nil, languageByHand: Bool = false, finished: Date? = nil,
                tags: [String] = [], about: String? = nil, aboutChecked: Date? = nil, detailsByHand: Bool = false) {
        self.id = id; self.title = title; self.author = author; self.coverURL = coverURL; self.series = series
        self.seriesNumber = seriesNumber; self.copies = copies; self.status = status
        self.statusByHand = statusByHand; self.wish = wish; self.removed = removed; self.progress = progress
        self.lastOpened = lastOpened; self.added = added; self.changed = changed
        self.rating = rating; self.note = note; self.gaveUp = gaveUp
        self.language = language; self.languageByHand = languageByHand; self.finished = finished
        self.tags = tags; self.about = about; self.aboutChecked = aboutChecked; self.detailsByHand = detailsByHand
        self.storeDetails = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, coverURL, series, seriesNumber, copies, status, statusByHand, wish, removed
        case progress, lastOpened, added, changed, rating, note, gaveUp, language, languageByHand, finished
        case tags, about, aboutChecked, detailsByHand, storeDetails
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        author = (try? c.decode(String.self, forKey: .author)) ?? ""
        coverURL = try? c.decodeIfPresent(String.self, forKey: .coverURL)
        series = try? c.decodeIfPresent(String.self, forKey: .series)
        seriesNumber = try? c.decodeIfPresent(Double.self, forKey: .seriesNumber)
        copies = ((try? c.decode([Lossy<BookCopy>].self, forKey: .copies)) ?? []).compactMap(\.value)
        status = (try? c.decode(ReadStatus.self, forKey: .status)) ?? .unread
        statusByHand = (try? c.decode(Bool.self, forKey: .statusByHand)) ?? false
        wish = (try? c.decode(Bool.self, forKey: .wish)) ?? false
        removed = (try? c.decode(Bool.self, forKey: .removed)) ?? false
        progress = try? c.decodeIfPresent(Double.self, forKey: .progress)
        lastOpened = try? c.decodeIfPresent(Date.self, forKey: .lastOpened)
        added = (try? c.decode(Date.self, forKey: .added)) ?? Date(timeIntervalSince1970: 0)
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? Date(timeIntervalSince1970: 0)
        rating = try? c.decodeIfPresent(Int.self, forKey: .rating)
        note = try? c.decodeIfPresent(String.self, forKey: .note)
        gaveUp = (try? c.decode(Bool.self, forKey: .gaveUp)) ?? false
        language = try? c.decodeIfPresent(String.self, forKey: .language)
        languageByHand = (try? c.decode(Bool.self, forKey: .languageByHand)) ?? false
        finished = try? c.decodeIfPresent(Date.self, forKey: .finished)
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        about = try? c.decodeIfPresent(String.self, forKey: .about)
        aboutChecked = try? c.decodeIfPresent(Date.self, forKey: .aboutChecked)
        detailsByHand = (try? c.decode(Bool.self, forKey: .detailsByHand)) ?? false
        storeDetails = try? c.decodeIfPresent(BookDetails.self, forKey: .storeDetails)
    }

    /// The day this book counts as finished: the day noted, else (a book finished before the day was kept)
    /// the day it was last opened. nil for a book that is not finished, or finished on a day nobody knows.
    public var finishedDay: Date? {
        guard status == .finished else { return nil }
        return finished ?? lastOpened
    }

    /// The stores this book is in, each once, in a fixed order.
    public var stores: [BookStore] {
        let order: [BookStore] = [.kobo, .kindle, .apple, .own]
        return order.filter { s in copies.contains { $0.store == s } }
    }
    public var isLockFree: Bool { copies.contains { $0.lockFree } }
    public var isAudio: Bool { copies.contains { $0.isAudio } }
    public var onlyAudio: Bool { !copies.isEmpty && copies.allSatisfy { $0.isAudio } }
    public var purchased: Date? { copies.compactMap(\.purchased).max() }

    /// The same kind (to read, or to listen to) held in two different stores.
    public var ownedTwice: Bool {
        for audio in [false, true] {
            let stores = Set(copies.filter { $0.isAudio == audio && $0.store != .own }.map(\.store))
            if stores.count > 1 { return true }
        }
        return false
    }
}

/// A book's title, author and place in a series.
public struct BookDetails: Codable, Equatable, Sendable {
    public var title: String
    public var author: String
    public var series: String?
    public var seriesNumber: Double?
    public init(title: String, author: String, series: String? = nil, seriesNumber: Double? = nil) {
        self.title = title; self.author = author; self.series = series; self.seriesNumber = seriesNumber
    }
}

/// When a store's list was last read on the Mac, and how many books it gave.
public struct ImportNote: Codable, Equatable, Sendable {
    public var date: Date
    public var count: Int
    public init(date: Date, count: Int) { self.date = date; self.count = count }
}

/// One volume of a series, as a catalogue lists it.
public struct SeriesVolume: Codable, Equatable, Sendable {
    public var number: Double
    public var title: String
    public init(number: Double, title: String) { self.number = number; self.title = title }
}

/// What a catalogue knows about a series: how many books it has and what they are called.
public struct SeriesInfo: Codable, Equatable, Sendable {
    public var total: Int?
    public var volumes: [SeriesVolume]
    public var checked: Date
    /// The owner typed the total himself: a catalogue no longer changes it.
    public var byHand: Bool
    public init(total: Int?, volumes: [SeriesVolume] = [], checked: Date = Date(), byHand: Bool = false) {
        self.total = total; self.volumes = volumes; self.checked = checked; self.byHand = byHand
    }

    enum CodingKeys: String, CodingKey { case total, volumes, checked, byHand }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
        volumes = (try? c.decode([SeriesVolume].self, forKey: .volumes)) ?? []
        checked = (try? c.decode(Date.self, forKey: .checked)) ?? Date(timeIntervalSince1970: 0)
        byHand = (try? c.decode(Bool.self, forKey: .byHand)) ?? false
    }
}

/// The whole shelf as it is kept in the file.
public struct LibraryData: Codable, Equatable, Sendable {
    /// Raised when a new version adds something an older version would lose by saving.
    /// 2 (version 0.3): stars, note and "gave up" on a book, and what is known about each series.
    /// 3 (version 0.5): the Up next list, the yearly goal, a book's language and finishing day, a series total typed by hand.
    /// 4 (version 0.6): tags, reading notes and their kinds, kept filters, the choice and order of shelves,
    /// corrected details, what a book is about, and what changed with each store's list.
    public static let currentFormat = 4

    public var format: Int
    public var books: [Book]
    public var imports: [String: ImportNote]
    /// Per series (its name written plainly): what a catalogue said about it.
    public var series: [String: SeriesInfo]
    /// The owner's own "Up next" list: book ids in the order he wants to read them.
    public var upNext: [String]
    /// When the Up next list last changed. Between two devices the newer list wins whole.
    public var upNextChanged: Date
    /// Books to finish in a year, by year ("2026": 24).
    public var goals: [String: Int]
    public var goalsChanged: Date
    /// The owner's reading notes, of every book. Between two devices the newer change of a note wins.
    public var notes: [ReadingNote]
    /// The kinds a note can have. Between two devices the newer list wins whole.
    public var noteKinds: [NoteKind]
    public var noteKindsChanged: Date
    /// Filters the owner kept as shelves of his own.
    public var savedFilters: [SavedFilter]
    /// The owner's order of the shelves on the main screen, and the ones he hid (see `LibraryData.orderKey`).
    public var shelfOrder: [String]
    public var hiddenShelves: [String]
    public var shelvesChanged: Date
    /// What came and left with the latest reads of the stores' lists, the newest first.
    public var changes: [ChangeEntry]

    public init(format: Int = LibraryData.currentFormat, books: [Book] = [], imports: [String: ImportNote] = [:],
                series: [String: SeriesInfo] = [:], upNext: [String] = [], upNextChanged: Date = Date(timeIntervalSince1970: 0),
                goals: [String: Int] = [:], goalsChanged: Date = Date(timeIntervalSince1970: 0),
                notes: [ReadingNote] = [], noteKinds: [NoteKind] = NoteKind.start,
                noteKindsChanged: Date = Date(timeIntervalSince1970: 0), savedFilters: [SavedFilter] = [],
                shelfOrder: [String] = [], hiddenShelves: [String] = [],
                shelvesChanged: Date = Date(timeIntervalSince1970: 0), changes: [ChangeEntry] = []) {
        self.format = format; self.books = books; self.imports = imports; self.series = series
        self.upNext = upNext; self.upNextChanged = upNextChanged; self.goals = goals; self.goalsChanged = goalsChanged
        self.notes = notes; self.noteKinds = noteKinds; self.noteKindsChanged = noteKindsChanged
        self.savedFilters = savedFilters; self.shelfOrder = shelfOrder; self.hiddenShelves = hiddenShelves
        self.shelvesChanged = shelvesChanged; self.changes = changes
    }

    enum CodingKeys: String, CodingKey {
        case format, books, imports, series, upNext, upNextChanged, goals, goalsChanged
        case notes, noteKinds, noteKindsChanged, savedFilters, shelfOrder, hiddenShelves, shelvesChanged, changes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? c.decode(Int.self, forKey: .format)) ?? 1
        books = ((try? c.decode([Lossy<Book>].self, forKey: .books)) ?? []).compactMap(\.value)
        imports = (try? c.decode([String: ImportNote].self, forKey: .imports)) ?? [:]
        series = (try? c.decode([String: SeriesInfo].self, forKey: .series)) ?? [:]
        upNext = (try? c.decode([String].self, forKey: .upNext)) ?? []
        upNextChanged = (try? c.decode(Date.self, forKey: .upNextChanged)) ?? Date(timeIntervalSince1970: 0)
        goals = (try? c.decode([String: Int].self, forKey: .goals)) ?? [:]
        goalsChanged = (try? c.decode(Date.self, forKey: .goalsChanged)) ?? Date(timeIntervalSince1970: 0)
        notes = ((try? c.decode([Lossy<ReadingNote>].self, forKey: .notes)) ?? []).compactMap(\.value)
        noteKinds = (try? c.decode([Lossy<NoteKind>].self, forKey: .noteKinds))?.compactMap(\.value) ?? NoteKind.start
        noteKindsChanged = (try? c.decode(Date.self, forKey: .noteKindsChanged)) ?? Date(timeIntervalSince1970: 0)
        savedFilters = ((try? c.decode([Lossy<SavedFilter>].self, forKey: .savedFilters)) ?? []).compactMap(\.value)
        shelfOrder = (try? c.decode([String].self, forKey: .shelfOrder)) ?? []
        hiddenShelves = (try? c.decode([String].self, forKey: .hiddenShelves)) ?? []
        shelvesChanged = (try? c.decode(Date.self, forKey: .shelvesChanged)) ?? Date(timeIntervalSince1970: 0)
        changes = ((try? c.decode([Lossy<ChangeEntry>].self, forKey: .changes)) ?? []).compactMap(\.value)
    }

    /// A file written by a newer version of the app: show it, change nothing.
    public var isNewer: Bool { format > Self.currentFormat }

    public static func decode(_ data: Data) throws -> LibraryData {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(LibraryData.self, from: data)
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    /// Two copies of the shelf (two devices, or iCloud's parked version) made into one:
    /// per book the newer change wins, and a book only one side knows is kept.
    public static func merged(_ a: LibraryData, _ b: LibraryData) -> LibraryData {
        var byID: [String: Book] = [:]
        var order: [String] = []
        for book in a.books + b.books {
            if let have = byID[book.id] {
                var winner = book.changed > have.changed ? book : have
                let other = book.changed > have.changed ? have : book
                // A cover found on one device is kept, whichever side holds the newer change.
                if winner.coverURL == nil, let cover = other.coverURL { winner.coverURL = cover }
                // The same for a language a store told or a guess found (not the owner's doing, so it never counts as a change).
                if winner.language == nil, !winner.languageByHand, let language = other.language { winner.language = language }
                // And for the finishing day of a book finished before the day was kept (see `tidy`).
                if winner.finished == nil, winner.status == .finished, let day = other.finished { winner.finished = day }
                // What a catalogue said the book is about is nobody's change either.
                if winner.about == nil, let about = other.about { winner.about = about }
                if let asked = other.aboutChecked, asked > (winner.aboutChecked ?? .distantPast) { winner.aboutChecked = asked }
                byID[book.id] = winner
            } else {
                byID[book.id] = book
                order.append(book.id)
            }
        }
        var imports = a.imports
        for (store, note) in b.imports where note.date > (imports[store]?.date ?? .distantPast) {
            imports[store] = note
        }
        var series = a.series
        for (name, info) in b.series {
            guard let mine = series[name] else { series[name] = info; continue }
            var newer = info.checked > mine.checked ? info : mine
            let older = info.checked > mine.checked ? mine : info
            // A total the owner typed on one device stays when the other device asked a catalogue later.
            if older.byHand, !newer.byHand { newer.total = older.total; newer.byHand = true }
            series[name] = newer
        }
        let nextSide = b.upNextChanged > a.upNextChanged ? b : a
        let goalSide = b.goalsChanged > a.goalsChanged ? b : a
        let kindSide = b.noteKindsChanged > a.noteKindsChanged ? b : a
        let shelfSide = b.shelvesChanged > a.shelvesChanged ? b : a
        // Notes and kept filters: one by one, the newer change wins (a removed one stays as a marker).
        func newest<T: Identifiable>(_ items: [T], changed: (T) -> Date) -> [T] where T.ID == String {
            var byID: [String: T] = [:]
            var order: [String] = []
            for item in items {
                if let have = byID[item.id] {
                    if changed(item) > changed(have) { byID[item.id] = item }
                } else {
                    byID[item.id] = item
                    order.append(item.id)
                }
            }
            return order.compactMap { byID[$0] }
        }
        var seen = Set<String>()
        let changes = (a.changes + b.changes).filter { seen.insert($0.id).inserted }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        return LibraryData(format: max(a.format, b.format), books: order.compactMap { byID[$0] }, imports: imports, series: series,
                           upNext: nextSide.upNext, upNextChanged: nextSide.upNextChanged,
                           goals: goalSide.goals, goalsChanged: goalSide.goalsChanged,
                           notes: newest(a.notes + b.notes) { $0.changed },
                           noteKinds: kindSide.noteKinds, noteKindsChanged: kindSide.noteKindsChanged,
                           savedFilters: newest(a.savedFilters + b.savedFilters) { $0.changed },
                           shelfOrder: shelfSide.shelfOrder, hiddenShelves: shelfSide.hiddenShelves,
                           shelvesChanged: shelfSide.shelvesChanged,
                           changes: Array(changes.prefix(ChangeEntry.kept)))
    }
}

/// One entry of a list that may hold something this version cannot read: it is skipped, the rest stays.
struct Lossy<T: Codable>: Codable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    func encode(to encoder: Encoder) throws { try value?.encode(to: encoder) }
}
