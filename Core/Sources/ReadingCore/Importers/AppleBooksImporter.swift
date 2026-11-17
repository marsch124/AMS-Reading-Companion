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
                "ZPATH", "ZCOVERURL", "ZSERIESID", "ZSEQUENCENUMBER", "ZSERIESCONTAINER", "ZKIND"])
            // Series containers: by primary key and by store id.
            var seriesByPK: [Int: String] = [:]
            var seriesByID: [String: String] = [:]
            for r in rows where r["ZCONTENTTYPE"]?.int == 5 {
                guard let t = r["ZTITLE"]?.string else { continue }
                if let pk = r["Z_PK"]?.int { seriesByPK[pk] = t }
                if let id = r["ZSTOREID"]?.string { seriesByID[id] = t }
                if let id = r["ZSERIESID"]?.string { seriesByID[id] = t }
            }
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
                    lastOpened: r["ZLASTOPENDATE"]?.double.map { Date(timeIntervalSince1970: $0 + coreDataEpoch) }))
            }
            return out
        }
    }
}
#endif
