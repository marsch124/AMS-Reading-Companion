import Foundation
#if os(macOS)

/// Reads the list of books from Kobo.sqlite (Kobo Desktop) or KoboReader.sqlite (e-reader).
/// Book rows are ContentType 6 with an empty BookID; rows with a BookID are chapters and are skipped.
public enum KoboImporter {
    public static func read(database: URL) throws -> [ImportedBook] {
        try SQLiteCopy.with(database) { copy in
            let rows = copy.rows(table: "content", wanted: [
                "ContentID", "ContentType", "BookID", "Title", "Attribution", "___PercentRead", "ReadStatus",
                "DateLastRead", "Series", "SeriesNumber", "ImageId", "MimeType", "Accessibility"])
            var out: [ImportedBook] = []
            for r in rows {
                guard r["ContentType"]?.string == "6" else { continue }
                if r["BookID"]?.string != nil { continue }
                guard let id = r["ContentID"]?.string, let title = r["Title"]?.string else { continue }
                let sideloaded = id.hasPrefix("file://")
                let mime = r["MimeType"]?.string?.lowercased() ?? ""
                let kind: BookKind = mime.contains("audio") ? .audiobook : (mime.contains("pdf") ? .pdf : .ebook)
                var path: String?
                if sideloaded { path = id.replacingOccurrences(of: "file://", with: "").removingPercentEncoding }
                let series = r["Series"]?.string
                out.append(ImportedBook(
                    store: sideloaded ? .own : .kobo, storeID: id, title: title,
                    author: r["Attribution"]?.string ?? "", kind: kind,
                    isSample: r["Accessibility"]?.int == 6, lockFree: sideloaded,
                    filePath: path,
                    coverURL: r["ImageId"]?.string.map { "https://cdn.kobo.com/book-images/\($0)/353/569/90/False/cover.jpg" },
                    series: series, seriesNumber: series == nil ? nil : r["SeriesNumber"]?.double,
                    progress: r["___PercentRead"]?.double.map { min(1, max(0, $0 / 100)) },
                    finished: r["ReadStatus"]?.int == 2,
                    purchased: nil,
                    lastOpened: r["DateLastRead"]?.string.flatMap(parseDate)))
            }
            return out
        }
    }

    static func parseDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
#endif
