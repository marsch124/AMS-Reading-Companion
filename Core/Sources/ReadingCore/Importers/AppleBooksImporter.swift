import Foundation
#if os(macOS)

/// Reads the list of books from Apple Books' library database.
/// Meaning of ZCONTENTTYPE (worked out from real data): 1 = epub book, 3 = PDF, 4 = book (store/series member),
/// 5 = SERIES CONTAINER row (skipped; its title is the series name of its members), 6 = audiobook.
public enum AppleBooksImporter {
    static let coreDataEpoch: TimeInterval = 978_307_200

    public static func read(folder: URL) throws -> [ImportedBook] {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("BKLibrary") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let db = files.last else { return [] }
        return try SQLiteCopy.with(db) { copy in
            let rows = copy.rows(table: "ZBKLIBRARYASSET", wanted: [
                "Z_PK", "ZASSETID", "ZSTOREID", "ZTITLE", "ZAUTHOR", "ZCONTENTTYPE", "ZISSAMPLE",
                "ZISSTOREAUDIOBOOK", "ZISFINISHED", "ZREADINGPROGRESS", "ZPURCHASEDATE", "ZLASTOPENDATE",
                "ZPATH", "ZCOVERURL", "ZSERIESID", "ZSEQUENCENUMBER", "ZSERIESCONTAINER", "ZKIND", "ZLANGUAGE"])
            // Series containers: by primary key and by store id.
            var seriesByPK: [Int: String] = [:]
            var seriesByID: [String: String] = [:]
            for r in rows where r["ZCONTENTTYPE"]?.int == 5 {
                guard let t = r["ZTITLE"]?.string else { continue }
                if let pk = r["Z_PK"]?.int { seriesByPK[pk] = t }
                if let id = r["ZSTOREID"]?.string { seriesByID[id] = t }
                if let id = r["ZSERIESID"]?.string { seriesByID[id] = t }
            }
            let memberships = ownCollections(copy, seriesTitles: Set(seriesByPK.values))
            var out: [ImportedBook] = []
            for r in rows {
                let type = r["ZCONTENTTYPE"]?.int
                if type == 5 { continue }
                guard let title = r["ZTITLE"]?.string else { continue }
                let storeID = r["ZSTOREID"]?.string
                let assetID = r["ZASSETID"]?.string
                guard let id = storeID ?? assetID else { continue }
                let path = r["ZPATH"]?.string
                let kindName = r["ZKIND"]?.string?.lowercased()
                let kind: BookKind
                if kindName == "pdf" || type == 3 || path?.lowercased().hasSuffix(".pdf") == true { kind = .pdf }
                else if type == 6 || r["ZISSTOREAUDIOBOOK"]?.int == 1 { kind = .audiobook }
                else { kind = .ebook }
                let own = (storeID == nil)
                var series: String?
                if let pk = r["ZSERIESCONTAINER"]?.int, let s = seriesByPK[pk] { series = s }
                else if let sid = r["ZSERIESID"]?.string, let s = seriesByID[sid] { series = s }
                var cover: String?
                if let c = r["ZCOVERURL"]?.string, c.hasPrefix("http://") || c.hasPrefix("https://") { cover = c }
                out.append(ImportedBook(
                    store: own ? .own : .apple, storeID: id, title: title,
                    author: r["ZAUTHOR"]?.string ?? "", kind: kind,
                    isSample: r["ZISSAMPLE"]?.int == 1, lockFree: own,
                    filePath: own ? path : nil, coverURL: cover,
                    series: series, seriesNumber: series == nil ? nil : r["ZSEQUENCENUMBER"]?.double,
                    progress: r["ZREADINGPROGRESS"]?.double.map { min(1, max(0, $0)) },
                    finished: r["ZISFINISHED"]?.int == 1,
                    purchased: r["ZPURCHASEDATE"]?.double.map { Date(timeIntervalSince1970: $0 + coreDataEpoch) },
                    lastOpened: r["ZLASTOPENDATE"]?.double.map { Date(timeIntervalSince1970: $0 + coreDataEpoch) },
                    language: BookLanguage.code(r["ZLANGUAGE"]?.string)))
                var names: [String] = []
                for key in [r["ZASSETID"]?.string, r["ZSTOREID"]?.string].compactMap({ $0 }).map({ "id:" + $0 })
                    + [r["Z_PK"]?.int.map { "pk:\($0)" }].compactMap({ $0 }) {
                    for n in memberships[key] ?? [] where !names.contains(n) { names.append(n) }
                }
                out[out.count - 1].collections = names.sorted()
            }
            return out
        }
    }

    /// The owner's OWN collections: keyed "id:<asset or store id>" and "pk:<asset row>" to collection names.
    /// Apple's built-in collections (Books, PDFs, Audiobooks, Finished, Want to Read, My Samples, Downloaded, Library,
    /// "My Books" ...) have ids like "Books_Collection_ID"; the owner's carry a UUID. Deleted, hidden and
    /// placeholder collections, and a collection named like a series, are left out. Missing tables: empty.
    static func ownCollections(_ copy: SQLiteCopy, seriesTitles: Set<String>) -> [String: [String]] {
        let cols = copy.rows(table: "ZBKCOLLECTION", wanted: [
            "Z_PK", "ZCOLLECTIONID", "ZTITLE", "ZDELETEDFLAG", "ZHIDDEN", "ZPLACEHOLDER"])
        var nameByPK: [Int: String] = [:]
        for c in cols {
            guard let pk = c["Z_PK"]?.int, let id = c["ZCOLLECTIONID"]?.string, isUUID(id),
                  let title = c["ZTITLE"]?.string, !seriesTitles.contains(title),
                  c["ZDELETEDFLAG"]?.int != 1, c["ZHIDDEN"]?.int != 1, c["ZPLACEHOLDER"]?.int != 1 else { continue }
            nameByPK[pk] = title
        }
        if nameByPK.isEmpty { return [:] }
        var out: [String: [String]] = [:]
        for m in copy.rows(table: "ZBKCOLLECTIONMEMBER", wanted: ["ZCOLLECTION", "ZASSET", "ZASSETID"]) {
            guard let cp = m["ZCOLLECTION"]?.int, let name = nameByPK[cp] else { continue }
            var keys: [String] = []
            if let a = m["ZASSETID"]?.string { keys.append("id:" + a) }
            if let a = m["ZASSET"]?.int { keys.append("pk:\(a)") }
            for k in keys where !(out[k] ?? []).contains(name) { out[k, default: []].append(name) }
        }
        return out
    }

    private static func isUUID(_ s: String) -> Bool { UUID(uuidString: s) != nil }
}
#endif
