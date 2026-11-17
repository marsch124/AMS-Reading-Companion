import Foundation

public enum CoverLookup {
    /// A cover picture address for a book known only by title and author (the Kindle books have no picture). nil when nothing fits.
    public static func find(title: String, author: String) async -> String? {
        let term = title + " " + LookupNet.plainAuthor(author)
        let apple = LookupNet.url("https://itunes.apple.com/search",
                                  [("term", term), ("entity", "ebook"), ("country", "se"), ("limit", "10")])
        if let data = await LookupNet.get(apple), let cover = parseApple(data, title: title, author: author) { return cover }
        let open = LookupNet.url("https://openlibrary.org/search.json",
                                 [("title", title), ("author", LookupNet.plainAuthor(author)), ("limit", "10"),
                                  ("fields", "title,author_name,cover_i")])
        if let data = await LookupNet.get(open) { return parseOpenLibrary(data, title: title, author: author) }
        return nil
    }

    /// First Apple Books hit that is the same book; the 100-point picture is asked for in 600 points.
    static func parseApple(_ data: Data, title: String, author: String) -> String? {
        guard let results = LookupNet.json(data)?["results"] as? [[String: Any]] else { return nil }
        for r in results {
            guard let name = r["trackName"] as? String, let by = r["artistName"] as? String,
                  BookMatch.same(title: title, author: author, title: name, author: by),
                  let art = r["artworkUrl100"] as? String, art.hasPrefix("http") else { continue }
            return art.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        }
        return nil
    }

    /// First Open Library hit that is the same book and has a cover.
    static func parseOpenLibrary(_ data: Data, title: String, author: String) -> String? {
        guard let docs = LookupNet.json(data)?["docs"] as? [[String: Any]] else { return nil }
        for d in docs {
            guard let name = d["title"] as? String, let id = d["cover_i"] as? Int,
                  let by = (d["author_name"] as? [String])?.first,
                  BookMatch.same(title: title, author: author, title: name, author: by) else { continue }
            return "https://covers.openlibrary.org/b/id/\(id)-L.jpg"
        }
        return nil
    }
}
