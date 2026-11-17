import Foundation

/// One book of the shelf, as small as the Share check needs it.
public struct ShelfEntry: Codable, Equatable, Hashable, Sendable {
    public var title: String
    public var author: String
    /// Store names as shown: "Kobo", "Kindle", "Apple Books", "Own file".
    public var stores: [String]
    public var wish: Bool
    public init(title: String, author: String, stores: [String], wish: Bool) {
        self.title = title; self.author = author; self.stores = stores; self.wish = wish
    }
}

/// The rules of the Share check: which shelf books a shared web page is about.
public enum ShareMatch {
    private static func words(_ text: String) -> [String] {
        BookMatch.plain(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static func contains(_ hay: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= hay.count else { return false }
        for i in 0...(hay.count - needle.count) where Array(hay[i..<(i + needle.count)]) == needle { return true }
        return false
    }

    /// The shelf books a shared web page is about. Best match first; empty when none fits.
    public static func find(pageTitle: String, in shelf: [ShelfEntry]) -> [ShelfEntry] {
        let page = words(pageTitle)
        guard !page.isEmpty else { return [] }
        let likelyKey = BookMatch.titleKey(likelyTitle(pageTitle))
        var hits: [(entry: ShelfEntry, length: Int, author: Bool)] = []
        for entry in shelf {
            let key = BookMatch.titleKey(entry.title)
            let keyWords = words(key)
            if !likelyKey.isEmpty {
                // A title could be cut out of the page: the book must be exactly that title.
                guard !key.isEmpty, key == likelyKey else { continue }
            } else {
                // No title to cut out: whole words anywhere in the page text.
                guard contains(page, keyWords) else { continue }
            }
            let last = BookMatch.authorKey(entry.author)
            let authorFound = !last.isEmpty && page.contains(last)
            let letters = key.filter { $0.isLetter || $0.isNumber }.count
            if likelyKey.isEmpty && letters < 5 && !authorFound { continue }
            hits.append((entry, letters, authorFound))
        }
        // Stable: author found first, then the longest title key, then shelf order.
        let indexed = hits.enumerated().sorted { a, b in
            if a.element.author != b.element.author { return a.element.author }
            if a.element.length != b.element.length { return a.element.length > b.element.length }
            return a.offset < b.offset
        }
        return indexed.map { $0.element.entry }
    }

    public static func likelyTitle(_ pageTitle: String) -> String { parse(pageTitle).title }
    public static func likelyAuthor(_ pageTitle: String) -> String { parse(pageTitle).author }

    // MARK: - Reading a page title

    private static func parse(_ raw: String) -> (title: String, author: String) {
        var s = raw.replacingOccurrences(of: "\u{200E}", with: "").replacingOccurrences(of: "\u{200F}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var author = ""

        // "Amazon.com: Title (isbn): Author: Books"
        if s.lowercased().hasPrefix("amazon."), let r = s.range(of: ": ") {
            s = String(s[r.upperBound...])
            let parts = s.components(separatedBy: ": ")
            if parts.count >= 2 {
                s = parts[0]
                let a = parts[1]
                if !a.lowercased().contains("kindle") && !a.lowercased().contains("books") { author = a }
            }
        } else if s.contains(" : ") {
            // "Title: Sub eBook : Vale, Una: Amazon.com: Kindle Store"
            let parts = s.components(separatedBy: " : ")
            s = parts[0]
            if parts.count > 1 {
                let a = parts[1].components(separatedBy: ": ")[0]
                if !a.lowercased().contains("amazon") && !a.lowercased().contains("kindle") { author = a }
            }
        } else {
            for mark in [" | ", " - ", " – ", " — "] {
                if let r = s.range(of: mark), s.distance(from: s.startIndex, to: r.lowerBound) >= 3 {
                    s = String(s[..<r.lowerBound])
                }
            }
        }
        // Apple Books: "Title on Apple Books"
        if let r = s.range(of: " on Apple Books", options: [.caseInsensitive, .backwards]) { s = String(s[..<r.lowerBound]) }
        // "Title eBook by Author"
        if let r = s.range(of: " by ", options: .backwards) {
            let a = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if author.isEmpty { author = a }
            s = String(s[..<r.lowerBound])
        }
        s = stripFormat(s.trimmingCharacters(in: .whitespaces))
        // "Vale, Una" -> "Una Vale"
        let parts = author.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty, !parts[0].contains(" ") { author = parts[1] + " " + parts[0] }
        return (s, author.trimmingCharacters(in: .whitespaces))
    }

    private static func stripFormat(_ title: String) -> String {
        var t = title
        for tail in [" (Kindle Edition)", " Kindle Edition", " eBook", " ebook", " Audiobook", " Hardcover", " Paperback"] {
            if t.lowercased().hasSuffix(tail.lowercased()) { t = String(t.dropLast(tail.count)).trimmingCharacters(in: .whitespaces) }
        }
        return t
    }
}
