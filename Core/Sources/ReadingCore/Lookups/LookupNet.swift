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
        await ask(url, accept: accept).data
    }

    /// The answer, and whether the catalogue was reached at all. "Not reached" (no network, a time-out, a busy or
    /// refusing server) must never be remembered as "the catalogue does not know this book".
    static func ask(_ url: URL?, accept: String = "application/json") async -> (data: Data?, reached: Bool) {
        guard let url else { return (nil, true) }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 8)
        // Says plainly what is asking; no name, no account, nothing about the device.
        request.setValue("AMSReadingCompanion/0.3 (personal book shelf app)", forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return (nil, false) }
            if (200..<300).contains(http.statusCode) { return (data, true) }
            // 404 = reached and not there; 403, 429 and 5xx = refused or busy, so not a real answer.
            return (nil, http.statusCode == 404)
        } catch {
            return (nil, false)
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
