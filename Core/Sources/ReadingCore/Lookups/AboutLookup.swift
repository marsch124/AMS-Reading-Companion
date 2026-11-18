import Foundation

/// What a catalogue said about a book's description. "Could not reach" is not "nothing known": the app asks again later.
public enum AboutAnswer: Sendable, Equatable {
    case found(String)
    case unknown
    case unreachable
}

public enum AboutLookup {
    /// The publisher's description of a book, as plain text. Only title and author are ever sent.
    public static func find(title: String, author: String) async -> AboutAnswer {
        let plain = LookupNet.plainAuthor(author)
        let term = title + " " + lastName(plain)
        var reachedAll = true

        for media in ["ebook", "audiobook"] {
            let url = LookupNet.url("https://itunes.apple.com/search",
                                    [("term", term), ("media", media), ("country", "se"), ("limit", "10")])
            let answer = await LookupNet.ask(url)
            if let data = answer.data, let text = parseApple(data, title: title, author: author) { return .found(text) }
            if !answer.reached { reachedAll = false }
        }

        let search = LookupNet.url("https://openlibrary.org/search.json",
                                   [("title", title), ("author", plain), ("limit", "5"),
                                    ("fields", "key,title,author_name")])
        let hits = await LookupNet.ask(search)
        if !hits.reached { reachedAll = false }
        if let data = hits.data, let key = parseOpenLibraryKey(data, title: title, author: author),
           key.hasPrefix("/"), let work = URL(string: "https://openlibrary.org" + key + ".json") {
            let answer = await LookupNet.ask(work)
            if let data = answer.data, let text = parseOpenLibraryWork(data) { return .found(text) }
            if !answer.reached { reachedAll = false }
        }
        return reachedAll ? .unknown : .unreachable
    }

    // MARK: - Parsing (no network)

    /// First Apple hit that is the same book and has a usable description, cleaned.
    static func parseApple(_ data: Data, title: String, author: String) -> String? {
        guard let results = LookupNet.json(data)?["results"] as? [[String: Any]] else { return nil }
        for r in results {
            guard let name = r["trackName"] as? String ?? r["collectionName"] as? String,
                  let by = r["artistName"] as? String,
                  BookMatch.same(title: title, author: author, title: name, author: by),
                  let text = r["description"] as? String, let cleaned = clean(text) else { continue }
            return cleaned
        }
        return nil
    }

    /// The work key ("/works/OL123W") of the first Open Library hit that is the same book.
    static func parseOpenLibraryKey(_ data: Data, title: String, author: String) -> String? {
        guard let docs = LookupNet.json(data)?["docs"] as? [[String: Any]] else { return nil }
        for d in docs {
            guard let name = d["title"] as? String, let key = d["key"] as? String,
                  let by = (d["author_name"] as? [String])?.first,
                  BookMatch.same(title: title, author: author, title: name, author: by) else { continue }
            return key
        }
        return nil
    }

    /// An Open Library work's description: either a string or `{ "value": "…" }`; cleaned.
    static func parseOpenLibraryWork(_ data: Data) -> String? {
        guard let json = LookupNet.json(data) else { return nil }
        if let s = json["description"] as? String { return clean(s) }
        if let o = json["description"] as? [String: Any], let s = o["value"] as? String { return clean(s) }
        return nil
    }

    private static func lastName(_ plain: String) -> String {
        plain.split(separator: " ").last.map(String.init) ?? plain
    }

    // MARK: - Cleaning

    /// A catalogue's description as plain text, at most about 2,000 characters; nil when under 40 characters remain.
    public static func clean(_ html: String) -> String? {
        var s = html
        s = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "</p\\s*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        s = decodeEntities(s)
        s = s.replacingOccurrences(of: "[ \\t\\x{00A0}]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " ?\\r?\\n ?", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 2000 {
            let head = String(s.prefix(2000))
            var end: String.Index?
            var i = head.startIndex
            while i < head.endIndex {
                if ".!?".contains(head[i]) { end = head.index(after: i) }
                i = head.index(after: i)
            }
            s = (end.map { String(head[..<$0]) } ?? head).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return s.count >= 40 ? s : nil
    }

    private static func decodeEntities(_ text: String) -> String {
        var s = text
        let named: [(String, String)] = [("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">")]
        for (k, v) in named { s = s.replacingOccurrences(of: k, with: v) }
        // Numeric: &#NNN; and &#xHH;
        if let re = try? NSRegularExpression(pattern: "&#([xX][0-9A-Fa-f]+|[0-9]+);") {
            let ns = s as NSString
            var out = "", last = 0
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let code = ns.substring(with: m.range(at: 1))
                let value = code.hasPrefix("x") || code.hasPrefix("X") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let v = value, let u = Unicode.Scalar(v) { out += String(Character(u)) } else { out += ns.substring(with: m.range) }
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            s = out
        }
        return s.replacingOccurrences(of: "&amp;", with: "&")   // last, so "&amp;lt;" stays "&lt;"
    }
}
