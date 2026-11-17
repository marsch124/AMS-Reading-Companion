import Foundation

public struct ISBNFound: Sendable, Equatable {
    public var title: String
    public var author: String
    public var coverURL: String?
    public init(title: String, author: String, coverURL: String? = nil) {
        self.title = title; self.author = author; self.coverURL = coverURL
    }
}

public enum ISBNLookup {
    /// The book behind a barcode number (ISBN-10 or ISBN-13, digits with or without dashes).
    public static func find(isbn: String) async -> ISBNFound? {
        guard let n = clean(isbn) else { return nil }
        let open = LookupNet.url("https://openlibrary.org/search.json",
                                 [("q", "isbn:" + n), ("fields", "title,author_name,cover_i"), ("limit", "1")])
        if let data = await LookupNet.get(open), let found = parseOpenLibrary(data) { return found }
        guard n.count == 13 else { return nil }
        let apple = LookupNet.url("https://itunes.apple.com/lookup", [("isbn", n), ("country", "se")])
        if let data = await LookupNet.get(apple) { return parseApple(data) }
        return nil
    }

    /// Digits only (a trailing X allowed on ISBN-10) with a valid check digit; nil otherwise.
    static func clean(_ isbn: String) -> String? {
        let s = isbn.uppercased().filter { $0.isNumber || $0 == "X" }
        let v = s.map { $0 == "X" ? 10 : ($0.wholeNumberValue ?? 0) }
        if s.count == 13, !s.contains("X") {
            let sum = v.enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
            return sum % 10 == 0 ? s : nil
        }
        if s.count == 10, !s.dropLast().contains("X") {
            let sum = v.enumerated().reduce(0) { $0 + $1.element * (10 - $1.offset) }
            return sum % 11 == 0 ? s : nil
        }
        return nil
    }

    static func parseOpenLibrary(_ data: Data) -> ISBNFound? {
        guard let d = (LookupNet.json(data)?["docs"] as? [[String: Any]])?.first,
              let title = d["title"] as? String, !title.isEmpty,
              let author = (d["author_name"] as? [String])?.first, !author.isEmpty else { return nil }
        let cover = (d["cover_i"] as? Int).map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
        return ISBNFound(title: title, author: author, coverURL: cover)
    }

    static func parseApple(_ data: Data) -> ISBNFound? {
        guard let r = (LookupNet.json(data)?["results"] as? [[String: Any]])?.first,
              let title = r["trackName"] as? String, !title.isEmpty,
              let author = r["artistName"] as? String, !author.isEmpty else { return nil }
        let cover = (r["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        return ISBNFound(title: title, author: author, coverURL: cover)
    }
}
