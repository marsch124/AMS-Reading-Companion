import Foundation

/// The one small network helper behind the four lookups: 8 seconds, never throws, nil on any doubt.
enum LookupNet {
    static func url(_ base: String, _ items: [(String, String)]) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#?/:;,")
        let query = items.compactMap { name, value -> String? in
            guard let v = value.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
            return "\(name)=\(v)"
        }.joined(separator: "&")
        return URL(string: query.isEmpty ? base : base + "?" + query)
    }

    static func get(_ url: URL?, accept: String = "application/json") async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (compatible; ReadingShelf/0.3)", forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    static func json(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// "Asimov, Isaac" -> "Isaac Asimov"; anything else unchanged.
    static func plainAuthor(_ author: String) -> String {
        let parts = author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, !parts[0].contains(" ") { return parts[1] + " " + parts[0] }
        return author.trimmingCharacters(in: .whitespaces)
    }
}
