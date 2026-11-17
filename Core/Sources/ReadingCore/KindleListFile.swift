import Foundation

/// A one-time list of the owner's whole Kindle library (the Kindle Mac app only remembers its latest sync).
/// Tolerant of two shapes: JSON (an array of objects) and CSV (comma, semicolon or tab). Never crashes:
/// rubbish in, empty list out.
public enum KindleListFile {
    public static func parse(_ data: Data) -> [ImportedBook] {
        guard !data.isEmpty else { return [] }
        var rows: [[String: Any]] = []
        if let json = try? JSONSerialization.jsonObject(with: data) {
            rows = jsonRows(json)
        } else if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            rows = csvRows(text)
        }
        var out: [ImportedBook] = []
        for row in rows {
            let title = (string(row, ["title", "name"]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let author = authorText(row)
            let asin = (string(row, ["asin"]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let purchased = date(row, ["purchased", "acquired", "date"])
            if asin.isEmpty {
                let lower = title.lowercased()
                var key = String(lower.filter { $0.isLetter })
                if key.isEmpty { key = String(lower.filter { $0.isLetter || $0.isNumber }) }
                guard !key.isEmpty else { continue }
                out.append(ImportedBook(store: .kindle, storeID: "title-" + key, title: title, author: author,
                                        kind: .ebook, purchased: purchased))
            } else {
                out.append(ImportedBook(store: .kindle, storeID: asin, title: title, author: author, kind: .ebook,
                                        coverURL: "https://m.media-amazon.com/images/P/\(asin).01._SCLZZZZZZZ_.jpg",
                                        purchased: purchased))
            }
        }
        return out
    }

    // MARK: JSON

    private static func jsonRows(_ json: Any) -> [[String: Any]] {
        if let array = json as? [Any] { return array.compactMap { ($0 as? [String: Any]).map(lowered) } }
        if let dict = json as? [String: Any] {
            for value in dict.values { if let array = value as? [Any], !array.isEmpty { return jsonRows(array) } }
        }
        return []
    }

    private static func lowered(_ d: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in d { out[k.lowercased()] = v }
        return out
    }

    // MARK: CSV

    private static func csvRows(_ raw: String) -> [[String: Any]] {
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let firstLine = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).first.map(String.init) ?? ""
        let delim = bestDelimiter(firstLine)
        let table = records(text, delimiter: delim)
        guard let head = table.first else { return [] }
        let names = head.map { $0.lowercased() }
        func column(_ keys: [String]) -> Int? { names.firstIndex { n in keys.contains { n.contains($0) } } }
        guard let t = column(["title"]) else { return [] }
        let a = column(["author"]), s = column(["asin"]), d = column(["date", "purchased", "acquired"])
        var rows: [[String: Any]] = []
        for r in table.dropFirst() {
            func cell(_ i: Int?) -> String? { i.flatMap { $0 < r.count ? r[$0] : nil } }
            var row: [String: Any] = [:]
            row["title"] = cell(t)
            if let v = cell(a) { row["author"] = v }
            if let v = cell(s) { row["asin"] = v }
            if let v = cell(d) { row["date"] = v }
            rows.append(row)
        }
        return rows
    }

    private static func bestDelimiter(_ line: String) -> Character {
        let candidates: [Character] = [",", ";", "\t"]
        return candidates.max { a, b in line.filter { $0 == a }.count < line.filter { $0 == b }.count } ?? ","
    }

    /// Quoted fields may hold the delimiter, doubled quotes and line breaks.
    private static func records(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"" {
                quoted = true
            } else if c == delimiter {
                row.append(field.trimmingCharacters(in: .whitespaces)); field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                row.append(field.trimmingCharacters(in: .whitespaces)); field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
            } else { field.append(c) }
            i += 1
        }
        return rows
    }

    // MARK: Fields

    private static func string(_ row: [String: Any], _ keys: [String]) -> String? {
        for k in keys {
            if let s = row[k] as? String { return s }
            if let n = row[k] as? NSNumber { return n.stringValue }
        }
        return nil
    }

    private static func authorText(_ row: [String: Any]) -> String {
        for k in ["author", "authors"] {
            if let s = row[k] as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let a = row[k] as? [Any] {
                return a.compactMap { $0 as? String }.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func date(_ row: [String: Any], _ keys: [String]) -> Date? {
        for k in keys {
            guard let v = row[k] else { continue }
            if let n = v as? NSNumber, !(v is Bool) { return fromNumber(n.doubleValue) }
            if let s = v as? String, let d = parseDate(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        }
        return nil
    }

    private static func fromNumber(_ x: Double) -> Date? {
        guard x > 0 else { return nil }
        return Date(timeIntervalSince1970: x > 1e11 ? x / 1000 : x)
    }

    private static func parseDate(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        if let n = Double(s) { return fromNumber(n) }
        let iso = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
            iso.formatOptions = options
            if let d = iso.date(from: s) { return d }
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "MMMM d, yyyy", "MMM d, yyyy", "d MMMM yyyy", "d MMM yyyy", "yyyy/MM/dd"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
