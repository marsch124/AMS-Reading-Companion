import Foundation

/// Reads the TEXT of a PDF the owner saved from Amazon's "Manage Your Content and Devices" page
/// (Books, sorted by Acquired). Never crashes: rubbish in, empty list out.
public enum KindlePDFText {
    /// True when the text looks like Amazon's content list.
    public static func looksRight(_ text: String) -> Bool {
        if text.contains("Manage Your Content and Devices") { return true }
        return text.split(whereSeparator: \.isNewline).contains { acquiredDate(String($0).trimmingCharacters(in: .whitespaces)) != nil }
    }

    /// "Showing 1 to 25 of 33 items" -> (shown: 25, total: 33).
    public static func counts(_ text: String) -> (shown: Int, total: Int)? {
        guard let re = try? NSRegularExpression(pattern: #"Showing\s+(\d+)\s+to\s+(\d+)\s+of\s+(\d+)\s+items"#),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r2 = Range(m.range(at: 2), in: text), let r3 = Range(m.range(at: 3), in: text),
              let shown = Int(text[r2]), let total = Int(text[r3]) else { return nil }
        return (shown, total)
    }

    /// Every book in the text.
    public static func parse(_ text: String) -> [ImportedBook] {
        enum Item { case text(String), read, acquired(Date?) }
        var items: [Item] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "READ" { items.append(.read); continue }
            if let d = acquiredDate(line) { items.append(.acquired(d)); continue }
            if isNoise(line) { continue }
            items.append(.text(decode(line)))
        }
        var out: [ImportedBook] = []
        var seen = Set<String>()
        var lastIndex: Int?
        for (i, item) in items.enumerated() {
            switch item {
            case .read:
                if let l = lastIndex, l < out.count { out[l].finished = true }
            case .acquired(let date):
                lastIndex = nil
                var found: [String] = []
                var j = i - 1
                while j >= 0, found.count < 2 {
                    guard case .text(let s) = items[j] else { break }
                    found.append(s); j -= 1
                }
                guard found.count == 2 else { continue }
                let author = found[0], title = found[1]
                let lower = title.lowercased()
                var key = String(lower.filter { $0.isLetter })
                if key.isEmpty { key = String(lower.filter { $0.isLetter || $0.isNumber }) }
                guard !key.isEmpty else { continue }
                guard seen.insert(key + "|" + author.lowercased()).inserted else { continue }
                out.append(ImportedBook(store: .kindle, storeID: "title-" + key, title: title, author: author,
                                        kind: .ebook, finished: false, purchased: date))
                lastIndex = out.count - 1
            case .text: break
            }
        }
        return out
    }

    // MARK: Lines

    private static func acquiredDate(_ line: String) -> Date?? {
        guard let re = try? NSRegularExpression(pattern: #"^(?:Acquired|Purchased|Borrowed) on ([A-Za-z]+) (\d{1,2}), (\d{4})$"#),
              let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let a = Range(m.range(at: 1), in: line), let b = Range(m.range(at: 2), in: line),
              let c = Range(m.range(at: 3), in: line) else { return nil }
        let months = ["january", "february", "march", "april", "may", "june", "july", "august",
                      "september", "october", "november", "december"]
        guard let mi = months.firstIndex(of: line[a].lowercased()), let d = Int(line[b]), let y = Int(line[c]) else {
            return .some(nil)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return .some(cal.date(from: DateComponents(year: y, month: mi + 1, day: d, hour: 12)))
    }

    private static let noiseExact: Set<String> = [
        "Deliver or remove from device", "Delete", "More actions", "Update available", "READ",
        "Amazon.com: Manage Your Content and Devices", "Go", "Select All", "Deselect All",
    ]
    private static let noisePrefixes = [
        "Shared with ", "Showing ", "Customer Service", "©", "http://", "https://", "Deliver to ",
        "Digital Content", "View:", "Search your content", "Search Amazon", "All Search Amazon",
        "Manage Your Content and Devices", "Deselect All", "Select All",
    ]

    private static func isNoise(_ line: String) -> Bool {
        if line.isEmpty || noiseExact.contains(line) { return true }
        if noisePrefixes.contains(where: { line.hasPrefix($0) }) { return true }
        let patterns = [#"^In \d+ (Devices?|Collections?)( \d+ Devices?)?$"#, #"^Page \d+ of \d+$"#,
                        #"^\d{4}-\d{2}-\d{2}, \d{1,2}:\d{2}$"#, #"^[\d\s]+$"#]
        return patterns.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    private static func decode(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
