import Foundation

/// The stores a book can come from. `own` = a file the owner brought himself (no store, no protection).
public enum BookStore: String, Codable, CaseIterable, Sendable { case kobo, kindle, apple, own }

public enum BookKind: String, Codable, Sendable { case ebook, audiobook, pdf }

/// One book as a store's local data lists it. Only a LIST entry: no book content is ever read.
public struct ImportedBook: Equatable, Sendable {
    public var store: BookStore
    /// Stable id inside that store: Kindle ASIN, Apple store id (else asset id), Kobo content id.
    public var storeID: String
    public var title: String
    public var author: String
    public var kind: BookKind
    public var isSample: Bool
    /// True ONLY when certain: the owner's own file, or the store's data says "no protection".
    public var lockFree: Bool
    /// Local file of a lock-free item, when known.
    public var filePath: String?
    public var coverURL: String?
    public var series: String?
    public var seriesNumber: Double?
    /// 0...1
    public var progress: Double?
    public var finished: Bool
    public var purchased: Date?
    public var lastOpened: Date?
    /// Lowercase two-letter language code ("sv", "de", "en"); nil when unknown.
    public var language: String?

    public init(store: BookStore, storeID: String, title: String, author: String = "",
                kind: BookKind = .ebook, isSample: Bool = false, lockFree: Bool = false,
                filePath: String? = nil, coverURL: String? = nil, series: String? = nil,
                seriesNumber: Double? = nil, progress: Double? = nil, finished: Bool = false,
                purchased: Date? = nil, lastOpened: Date? = nil, language: String? = nil) {
        self.store = store; self.storeID = storeID; self.title = title; self.author = author
        self.kind = kind; self.isSample = isSample; self.lockFree = lockFree
        self.filePath = filePath; self.coverURL = coverURL; self.series = series
        self.seriesNumber = seriesNumber; self.progress = progress; self.finished = finished
        self.purchased = purchased; self.lastOpened = lastOpened; self.language = language
    }
}
