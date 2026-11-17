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

    public init(id: String, title: String, author: String = "", coverURL: String? = nil, series: String? = nil,
                seriesNumber: Double? = nil, copies: [BookCopy] = [], status: ReadStatus = .unread,
                statusByHand: Bool = false, wish: Bool = false, removed: Bool = false, progress: Double? = nil,
                lastOpened: Date? = nil, added: Date = Date(), changed: Date = Date(),
                rating: Int? = nil, note: String? = nil, gaveUp: Bool = false) {
        self.id = id; self.title = title; self.author = author; self.coverURL = coverURL; self.series = series
        self.seriesNumber = seriesNumber; self.copies = copies; self.status = status
        self.statusByHand = statusByHand; self.wish = wish; self.removed = removed; self.progress = progress
        self.lastOpened = lastOpened; self.added = added; self.changed = changed
        self.rating = rating; self.note = note; self.gaveUp = gaveUp
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, coverURL, series, seriesNumber, copies, status, statusByHand, wish, removed
        case progress, lastOpened, added, changed, rating, note, gaveUp
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
    public init(total: Int?, volumes: [SeriesVolume] = [], checked: Date = Date()) {
        self.total = total; self.volumes = volumes; self.checked = checked
    }
}

/// The whole shelf as it is kept in the file.
public struct LibraryData: Codable, Equatable, Sendable {
    /// Raised when a new version adds something an older version would lose by saving.
    /// 2 (version 0.3): stars, note and "gave up" on a book, and what is known about each series.
    public static let currentFormat = 2

    public var format: Int
    public var books: [Book]
    public var imports: [String: ImportNote]
    /// Per series (its name written plainly): what a catalogue said about it.
    public var series: [String: SeriesInfo]

    public init(format: Int = LibraryData.currentFormat, books: [Book] = [], imports: [String: ImportNote] = [:],
                series: [String: SeriesInfo] = [:]) {
        self.format = format; self.books = books; self.imports = imports; self.series = series
    }

    enum CodingKeys: String, CodingKey { case format, books, imports, series }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? c.decode(Int.self, forKey: .format)) ?? 1
        books = ((try? c.decode([Lossy<Book>].self, forKey: .books)) ?? []).compactMap(\.value)
        imports = (try? c.decode([String: ImportNote].self, forKey: .imports)) ?? [:]
        series = (try? c.decode([String: SeriesInfo].self, forKey: .series)) ?? [:]
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
                if book.changed > have.changed { byID[book.id] = book }
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
        for (name, info) in b.series where info.checked > (series[name]?.checked ?? .distantPast) {
            series[name] = info
        }
        return LibraryData(format: max(a.format, b.format), books: order.compactMap { byID[$0] }, imports: imports, series: series)
    }
}

/// One entry of a list that may hold something this version cannot read: it is skipped, the rest stays.
struct Lossy<T: Codable>: Codable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    func encode(to encoder: Encoder) throws { try value?.encode(to: encoder) }
}
