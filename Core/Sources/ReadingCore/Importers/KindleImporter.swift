import Foundation
#if os(macOS)

/// Reads Kindle for Mac's local data. The only readable list with titles is `Cache/KindleSyncMetadataCache.xml`
/// (title, authors, ASIN, purchase date, type). NOTE: that file holds only what the last sync added or updated,
/// not necessarily the full library; `My Kindle Content/book_asset.db` lists downloaded ASINs only (no titles).
public enum KindleImporter {
    public static func read(folder: URL) throws -> [ImportedBook] {
        let xml = folder.appendingPathComponent("Cache/KindleSyncMetadataCache.xml")
        guard let data = try? Data(contentsOf: xml) else { return [] }
        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.parse()

        // Samples known from book_asset.db (sampling flag), when readable.
        var sampleASINs = Set<String>()
        let assetDB = folder.appendingPathComponent("My Kindle Content/book_asset.db")
        if FileManager.default.fileExists(atPath: assetDB.path) {
            let rows = (try? SQLiteCopy.with(assetDB) { $0.rows(table: "Book", wanted: ["asin", "sampling"]) }) ?? []
            for r in rows {
                let s = r["sampling"]?.string?.lowercased() ?? ""
                if ["true", "1", "yes", "sample"].contains(s), let a = r["asin"]?.string { sampleASINs.insert(a) }
            }
        }
        let content = folder.appendingPathComponent("My Kindle Content")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: content.path)) ?? []

        var seen = Set<String>(), out: [ImportedBook] = []
        for m in delegate.items {
            guard let asin = m["ASIN"], !asin.isEmpty, let title = m["title"], !title.isEmpty, seen.insert(asin).inserted else { continue }
            let type = (m["cde_contenttype"] ?? "").uppercased()
            let personal = type == "PDOC"
            let mime = (m["content_type"] ?? "").lowercased()
            var path: String?
            if personal, let f = names.first(where: { $0.hasPrefix(asin + "_PDOC") && !$0.hasSuffix(".phl") && !$0.hasSuffix(".apnx") && !$0.hasSuffix(".mbpV2") }) {
                path = content.appendingPathComponent(f).path
            }
            out.append(ImportedBook(
                store: personal ? .own : .kindle, storeID: asin, title: title,
                author: authors(m["authors"] ?? ""), kind: mime.contains("pdf") ? .pdf : .ebook,
                isSample: type == "EBSP" || sampleASINs.contains(asin), lockFree: personal,
                filePath: path,
                coverURL: personal ? nil : "https://m.media-amazon.com/images/P/\(asin).01._SCLZZZZZZZ_.jpg",
                purchased: date(m["purchase_date"])))
        }
        return out
    }

    /// "McKean, Erin" -> "Erin McKean"; duplicates dropped; joined with ", ".
    static func authors(_ joined: String) -> String {
        var names: [String] = []
        for raw in joined.components(separatedBy: "\u{1F}") {
            var n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = n.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty { n = parts[1] + " " + parts[0] }
            if !n.isEmpty, !names.contains(n) { names.append(n) }
        }
        return names.joined(separator: ", ")
    }

    static func date(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.date(from: s)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var items: [[String: String]] = []
        private var current: [String: String]?
        private var text = ""
        private var authorList: [String] = []
        func parser(_ p: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            text = ""
            if name == "meta_data" { current = [:]; authorList = [] }
        }
        func parser(_ p: XMLParser, foundCharacters s: String) { text += s }
        func parser(_ p: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            guard current != nil else { return }
            switch name {
            case "meta_data":
                current?["authors"] = authorList.joined(separator: "\u{1F}")
                if let c = current { items.append(c) }
                current = nil
            case "author": authorList.append(text)
            case "ASIN", "title", "purchase_date", "cde_contenttype", "content_type":
                current?[name] = text.trimmingCharacters(in: .whitespacesAndNewlines)
            default: break
            }
        }
    }
}
#endif
