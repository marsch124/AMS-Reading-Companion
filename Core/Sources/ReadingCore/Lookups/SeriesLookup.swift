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
        guard let query = sparql(knownTitle: knownTitle, author: author) else { return nil }
        var comps = URLComponents(string: "https://query.wikidata.org/sparql")
        comps?.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "format", value: "json")]
        guard let url = comps?.url,
              let data = await LookupNet.get(url, accept: "application/sparql-results+json") else { return nil }
        return parse(data, series: series)
    }

    static func sparql(knownTitle: String, author: String) -> String? {
        var title = knownTitle.trimmingCharacters(in: .whitespaces)
        if let r = title.range(of: " (") { title = String(title[..<r.lowerBound]) }   // "Dune (Dune Chronicles #1)"
        let last = BookMatch.authorKey(author)
        guard !title.isEmpty, !last.isEmpty, last.count >= 2 else { return nil }
        let t = title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return """
        SELECT DISTINCT ?sLabel ?bLabel ?ord WHERE {
          ?k rdfs:label "\(t)"@en; wdt:P50 ?a. ?a rdfs:label ?al.
          FILTER(LANG(?al)="en" && CONTAINS(LCASE(?al), "\(last)"))
          ?k wdt:P179 ?s. ?b p:P179 ?bs. ?bs ps:P179 ?s. ?b wdt:P50 ?a.
          OPTIONAL { ?bs pq:P1545 ?ord }
          ?s rdfs:label ?sLabel. ?b rdfs:label ?bLabel.
          FILTER(LANG(?sLabel)="en" && LANG(?bLabel)="en")
        }
        """
    }

    private static func seriesKey(_ name: String) -> String {
        let drop: Set<String> = ["series", "trilogy", "saga", "cycle", "chronicles", "books", "novels", "the"]
        return BookMatch.plain(name).split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { !drop.contains($0) }.joined(separator: " ")
    }

    /// Only a series with the asked-for name counts; several of them (a trilogy inside a bigger series): the biggest.
    static func parse(_ data: Data, series: String) -> SeriesFound? {
        guard let rows = (LookupNet.json(data)?["results"] as? [String: Any])?["bindings"] as? [[String: Any]] else { return nil }
        let want = seriesKey(series)
        guard !want.isEmpty else { return nil }
        func value(_ row: [String: Any], _ key: String) -> String? { (row[key] as? [String: Any])?["value"] as? String }

        var groups: [String: [Double: String]] = [:]
        for row in rows {
            guard let s = value(row, "sLabel"), seriesKey(s) == want,
                  let b = value(row, "bLabel"), let o = value(row, "ord"), let n = Double(o), n > 0 else { continue }
            if let have = groups[s]?[n], have <= b { continue }          // two books on one number: keep one, steadily
            groups[s, default: [:]][n] = b
        }
        guard let best = groups.sorted(by: { ($0.value.count, $1.key) > ($1.value.count, $0.key) }).first?.value, !best.isEmpty else { return nil }
        let volumes = best.keys.sorted().map { SeriesVolume(number: $0, title: best[$0] ?? "") }
        let total = max(volumes.count, Int(volumes.last?.number ?? 0))
        return SeriesFound(total: total, volumes: volumes)
    }
}
