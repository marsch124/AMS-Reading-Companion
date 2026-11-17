#if canImport(CoreText)
import CoreGraphics
import XCTest
@testable import ReadingCore

final class ShelfListPDFTests: XCTestCase {
    private func pages(_ d: Data) -> Int? {
        guard let p = CGDataProvider(data: d as CFData), let doc = CGPDFDocument(p) else { return nil }
        return doc.numberOfPages
    }

    func testSampleShelfMakesAPDF() throws {
        let d = ShelfListPDF.make(LibraryData.sample, now: Date(timeIntervalSince1970: 1_794_000_000))
        XCTAssertGreaterThanOrEqual(pages(d) ?? 0, 1)
        if let dir = ProcessInfo.processInfo.environment["LIST_PDF_OUT"] { try d.write(to: URL(fileURLWithPath: dir)) }
    }

    func testLongShelfNeedsSeveralPages() {
        var data = LibraryData()
        for n in 0..<200 {
            data.books.append(Book(id: "made-up-\(n)", title: "Made-up book number \(n) with a rather long title that must be cut", author: "Author \(n)"))
        }
        XCTAssertGreaterThan(pages(ShelfListPDF.make(data)) ?? 0, 1)
    }
}
#endif
