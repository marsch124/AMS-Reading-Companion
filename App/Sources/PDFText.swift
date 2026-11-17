import Foundation
import PDFKit

/// The plain text of a PDF (every page, joined by a newline). Works on iOS and macOS.
enum PDFText {
    static func text(of url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let s = doc.page(at: i)?.string { pages.append(s) }
        }
        let joined = pages.joined(separator: "\n")
        return joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : joined
    }
}
