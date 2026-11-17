import Foundation

public struct PriceFound: Sendable, Equatable {
    public var price: String
    public var url: String
    public init(price: String, url: String) { self.price = price; self.url = url }
}

public enum PriceLookup {
    /// Apple Books' price for an ebook in one country's store ("se" = Sweden, prices in SEK).
    public static func apple(title: String, author: String, country: String) async -> PriceFound? {
        let code = country.lowercased()
        guard code.count == 2, code.allSatisfy({ $0.isLetter }) else { return nil }
        let url = LookupNet.url("https://itunes.apple.com/search",
                                [("term", title + " " + LookupNet.plainAuthor(author)), ("entity", "ebook"),
                                 ("country", code), ("limit", "10")])
        guard let data = await LookupNet.get(url) else { return nil }
        return parseApple(data, title: title, author: author)
    }

    /// Kobo's search page (Sweden, English), opened by the owner himself.
    public static func koboSearch(title: String, author: String) -> URL? {
        LookupNet.url("https://www.kobo.com/se/en/search", [("query", title + " " + LookupNet.plainAuthor(author))])
    }

    /// Amazon Sweden's Kindle-books search page, opened by the owner himself.
    public static func kindleSearch(title: String, author: String) -> URL? {
        LookupNet.url("https://www.amazon.com/s", [("k", title + " " + LookupNet.plainAuthor(author)), ("i", "digital-text")])
    }

    /// Apple lists several editions of one book at different prices. Take the best-ranked edition of the same
    /// book that is not free (free ones are usually bare public-domain copies); free only when nothing else.
    static func parseApple(_ data: Data, title: String, author: String) -> PriceFound? {
        guard let results = LookupNet.json(data)?["results"] as? [[String: Any]] else { return nil }
        var free: PriceFound?
        for r in results {
            guard let name = r["trackName"] as? String, let by = r["artistName"] as? String,
                  BookMatch.same(title: title, author: author, title: name, author: by),
                  let shown = r["formattedPrice"] as? String, !shown.isEmpty else { continue }
            let link = (r["trackViewUrl"] as? String) ?? ""
            let found = PriceFound(price: shown, url: link)
            if let amount = r["price"] as? Double, amount > 0 { return found }
            if free == nil { free = found }
        }
        return free
    }
}
