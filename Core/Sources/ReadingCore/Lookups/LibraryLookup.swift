import Foundation

/// The forms in which Swedish libraries hold a book.
public enum LibraryForm: String, Codable, Sendable, CaseIterable {
    case book, ebook, audiobook

    public var name: String {
        switch self {
        case .book: return "Paper book"
        case .ebook: return "E-book"
        case .audiobook: return "Audiobook"
        }
    }
}

/// What the national catalogue LIBRIS says about a book. `atHome` stays nil: LIBRIS's open search does not say
/// which library holds a copy, so "your own library has it" is not known and is never guessed.
public struct LibraryFinding: Codable, Equatable, Sendable {
    public var forms: [LibraryForm]
    public var atHome: Bool?
    public var link: String
    public var checked: Date

    public init(forms: [LibraryForm], atHome: Bool? = nil, link: String, checked: Date) {
        self.forms = forms; self.atHome = atHome; self.link = link; self.checked = checked
    }
}

/// "Could not reach" is never "not in the catalogue": the app asks again later.
public enum LibraryAnswer: Equatable, Sendable {
    case found(LibraryFinding)
    case unknown
    case unreachable
}

public enum LibraryLookup {
    /// The search address. Only title, the author's last name and the ISBN can ever be in it.
    public static func query(title: String, author: String, isbn: String?) -> URL? {
        let last = BookMatch.authorKey(author)
        let digits = (isbn ?? "").filter { $0.isNumber || $0 == "X" || $0 == "x" }
        let term: String
        if digits.count == 10 || digits.count == 13 {
            term = "isbn:" + digits
        } else {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            term = last.isEmpty ? t : t + " " + last
        }
        return LookupNet.url("https://libris.kb.se/xsearch",
                             [("query", term), ("format", "json"), ("n", "40")])
    }

    /// The page a person opens to see the hits in LIBRIS.
    public static func page(title: String, author: String) -> URL? {
        let last = BookMatch.authorKey(author)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return LookupNet.url("https://libris.kb.se/hitlist",
                             [("d", "libris"), ("q", last.isEmpty ? t : t + " " + last)])
    }

    /// Reads a LIBRIS answer (no network). Only records whose title AND the author's last name match count.
    public static func read(_ data: Data, title: String, author: String, now: Date) -> LibraryAnswer {
        guard let root = LookupNet.json(data)?["xsearch"] as? [String: Any] else { return .unreachable }
        var records = root["list"] as? [[String: Any]] ?? []
        if records.isEmpty, let one = root["list"] as? [String: Any] { records = [one] }
        var forms = Set<LibraryForm>()
        for r in records {
            guard let name = r["title"] as? String,
                  BookMatch.same(title: title, author: author, title: name, author: creator(r)) else { continue }
            let kinds = (r["type"] as? [String]) ?? [(r["type"] as? String) ?? ""]
            for kind in kinds {
                switch kind.lowercased() {
                case "book", "text": forms.insert(.book)
                case "e-book": forms.insert(.ebook)
                case "sound recording": forms.insert(.audiobook)
                default: break
                }
            }
        }
        guard !forms.isEmpty else { return .unknown }
        let link = page(title: title, author: author)?.absoluteString ?? "https://libris.kb.se"
        return .found(LibraryFinding(forms: LibraryForm.allCases.filter(forms.contains), atHome: nil, link: link, checked: now))
    }

    /// Asks LIBRIS. A failed request is `.unreachable`, never `.unknown`.
    public static func look(title: String, author: String, isbn: String?) async -> LibraryAnswer {
        guard let url = query(title: title, author: author, isbn: isbn) else { return .unknown }
        let answer = await LookupNet.ask(url)
        guard answer.reached, let data = answer.data else { return .unreachable }
        var result = read(data, title: title, author: author, now: Date())
        // An ISBN hit may be titled differently from the shelf; fall back to the plain title search.
        if result == .unknown, url.absoluteString.contains("isbn%3A") || url.absoluteString.contains("isbn:"),
           let plain = query(title: title, author: author, isbn: nil) {
            let second = await LookupNet.ask(plain)
            guard second.reached, let data = second.data else { return .unreachable }
            result = read(data, title: title, author: author, now: Date())
        }
        return result
    }

    private static func creator(_ r: [String: Any]) -> String {
        (r["creator"] as? String) ?? (r["creator"] as? [String])?.first ?? ""
    }
}
