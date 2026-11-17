import Foundation

public struct SeriesFound: Sendable, Equatable {
    public var total: Int?
    public var volumes: [SeriesVolume]
    public init(total: Int?, volumes: [SeriesVolume]) { self.total = total; self.volumes = volumes }
}

/// Source: Wikidata's public query service (one request). It finds the owner's book by its English title and
/// author, follows "part of the series" and lists every book of that series by the same author with its number.
/// It only answers when the series name matches the one given; it returns nil rather than guess.
public enum SeriesLookup {
    /// How many books a series has and what they are called. `knownTitle` is one book of the series the owner has.
    public static func find(series: String, author: String, knownTitle: String) async -> SeriesFound? {
        await ask(series: series, author: author, knownTitle: knownTitle).found
    }

    /// The series, and whether the catalogue really answered: `answered` is false when it could not be reached,
    /// so the app asks again next time instead of noting "unknown" for two months.
    public static func ask(series: String, author: String, knownTitle: String) async -> (found: SeriesFound?, answered: Bool) {
        guard let query = sparql(knownTitle: knownTitle, author: author) else { return (nil, true) }
        var comps = URLComponents(string: "https://query.wikidata.org/sparql")
        comps?.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "format", value: "json")]
        guard let url = comps?.url else { return (nil, true) }
        let answer = await LookupNet.ask(url, accept: "application/sparql-results+json")
        guard let data = answer.data else { return (nil, answer.reached) }
        return (parse(data, series: series), true)
    }

    static func sparql(knownTitle: String, author: String) -> String? {
        var title = knownTitle.trimmingCharacters(in: .whitespaces)
        if let r = title.range(of: " (") { title = String(title[..<r.lowerBound]) }   // "Dune (Dune Chronicles #1)"
        // The author's last name as written (with its accents: the catalogue writes "Läckberg", not "Lackberg").
        let last = LookupNet.plainAuthor(author).split(separator: " ").last.map { $0.lowercased() } ?? ""
        guard !title.isEmpty, last.count >= 2 else { return nil }
        func quoted(_ text: String) -> String {
            text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        let t = quoted(title), l = quoted(last)
        // The owner's book is looked for by its title in English, Swedish or German. Volume titles come back in the
        // language the title was found in, else in English.
        return """
        SELECT DISTINCT ?s ?sLabel ?b ?bLabel ?bEn ?ord WHERE {
          VALUES ?kl { "\(t)"@en "\(t)"@sv "\(t)"@de }
          ?k rdfs:label ?kl; wdt:P50 ?a. ?a rdfs:label ?al.
          FILTER(LANG(?al)="en" && CONTAINS(LCASE(?al), "\(l)"))
          ?k wdt:P179 ?s. ?b p:P179 ?bs. ?bs ps:P179 ?s. ?b wdt:P50 ?a.
          FILTER NOT EXISTS { ?b wdt:P50 ?other. FILTER(?other != ?a) }
          OPTIONAL { ?bs pq:P1545 ?ord }
          ?s rdfs:label ?sLabel. FILTER(LANG(?sLabel) IN ("en", "sv", "de"))
          OPTIONAL { ?b rdfs:label ?bLabel. FILTER(LANG(?bLabel) = LANG(?kl)) }
          OPTIONAL { ?b rdfs:label ?bEn. FILTER(LANG(?bEn) = "en") }
        }
        """
    }

    private static func seriesKey(_ name: String) -> String {
        let drop: Set<String> = ["series", "trilogy", "saga", "cycle", "chronicles", "books", "novels", "the"]
        return BookMatch.plain(name).split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { !drop.contains($0) }.joined(separator: " ")
    }

    /// The series the owner's book belongs to. A series whose name is the one given wins; when the catalogue
    /// files the book under exactly one series, that one is taken even under another name (a store's name for a
    /// series often differs from the catalogue's). A series in which two books share a number is not trusted.
    static func parse(_ data: Data, series: String) -> SeriesFound? {
        guard let rows = (LookupNet.json(data)?["results"] as? [String: Any])?["bindings"] as? [[String: Any]] else { return nil }
        let want = seriesKey(series)
        func value(_ row: [String: Any], _ key: String) -> String? { (row[key] as? [String: Any])?["value"] as? String }

        var books: [String: [Double: String]] = [:]      // series -> number -> which book
        var titles: [String: [Double: String]] = [:]     // series -> number -> its title
        var named: Set<String> = []                      // series whose name is the one asked for
        var muddled: Set<String> = []
        for row in rows {
            let label = value(row, "sLabel") ?? ""
            let sid = value(row, "s") ?? label
            guard !sid.isEmpty else { continue }
            if !want.isEmpty, seriesKey(label) == want { named.insert(sid) }
            guard let o = value(row, "ord"), let n = Double(o), n.isFinite, n > 0, n < 1_000_000 else { continue }
            let title = value(row, "bLabel") ?? value(row, "bEn") ?? ""
            let bid = value(row, "b") ?? title
            if let have = books[sid]?[n], have != bid { muddled.insert(sid); continue }
            books[sid, default: [:]][n] = bid
            if !title.isEmpty, titles[sid]?[n] == nil || value(row, "bLabel") != nil { titles[sid, default: [:]][n] = title }
        }
        for sid in muddled { books[sid] = nil }
        let chosen: String?
        if let best = books.filter({ named.contains($0.key) }).sorted(by: { ($0.value.count, $1.key) > ($1.value.count, $0.key) }).first {
            chosen = best.key
        } else if named.isEmpty, books.count == 1, muddled.isEmpty {
            chosen = books.keys.first
        } else {
            chosen = nil
        }
        guard let sid = chosen, let numbers = books[sid], !numbers.isEmpty else { return nil }
        let volumes = numbers.keys.sorted().map { SeriesVolume(number: $0, title: titles[sid]?[$0] ?? "") }
        let total = max(volumes.count, Int(volumes.last?.number ?? 0))
        return SeriesFound(total: total, volumes: volumes)
    }
}
