import XCTest
@testable import ReadingCore

/// The four lookups, tested on trimmed copies of real answers (famous books only). No network.
final class LookupTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }

    private let apple = """
    {"resultCount":2,"results":[
    {"formattedPrice":"89,00 kr","artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/Publication122/v4/85/70/2f/x/9781101658055.d.jpg/100x100bb.jpg","trackCensoredName":"Dune","trackViewUrl":"https:\\/\\/books.apple.com\\/se\\/book\\/dune\\/id597944491?uo=4","artistName":"Frank Herbert","price":89.00,"currency":"SEK","kind":"ebook","trackName":"Dune"},
    {"formattedPrice":"249,00 kr","artworkUrl100":"https://example.com/b/100x100bb.jpg","trackViewUrl":"https://books.apple.com/se/book/x/id1","artistName":"Frank Herbert","price":249.00,"trackName":"Dune: The Gateway Collection"}]}
    """

    func testCoverFromApple() {
        let url = CoverLookup.parseApple(d(apple), title: "Dune", author: "Herbert, Frank")
        XCTAssertEqual(url?.hasSuffix("/600x600bb.jpg"), true)
        XCTAssertNil(CoverLookup.parseApple(d(apple), title: "Foundation", author: "Isaac Asimov"))
    }

    func testCoverFromOpenLibrary() {
        let json = #"{"numFound":2,"docs":[{"author_name":["Frank Herbert"],"cover_i":980253,"title":"Dune Messiah"},{"author_name":["Frank Herbert"],"cover_i":11481354,"title":"Dune"}]}"#
        XCTAssertEqual(CoverLookup.parseOpenLibrary(d(json), title: "Dune", author: "Frank Herbert"),
                       "https://covers.openlibrary.org/b/id/11481354-L.jpg")
        XCTAssertNil(CoverLookup.parseOpenLibrary(d(json), title: "Dune", author: "Isaac Asimov"))   // wrong author
    }

    func testApplePriceAndWrongBook() {
        let found = PriceLookup.parseApple(d(apple), title: "Dune", author: "Frank Herbert")
        XCTAssertEqual(found?.price, "89,00 kr")
        XCTAssertEqual(found?.url, "https://books.apple.com/se/book/dune/id597944491?uo=4")
        XCTAssertNil(PriceLookup.parseApple(d(apple), title: "Neuromancer", author: "William Gibson"))
        XCTAssertNotNil(PriceLookup.koboSearch(title: "Dune", author: "Herbert, Frank"))
        XCTAssertEqual(PriceLookup.kindleSearch(title: "Dune & More", author: "Frank Herbert")?.absoluteString,
                       "https://www.amazon.se/s?k=Dune%20%26%20More%20Frank%20Herbert&i=digital-text")
    }

    func testISBN() {
        XCTAssertEqual(ISBNLookup.clean("978-0-441-17271-9"), "9780441172719")
        XCTAssertEqual(ISBNLookup.clean("0553293354"), "0553293354")
        XCTAssertNil(ISBNLookup.clean("9780441172718"))     // wrong check digit
        let json = #"{"numFound":1,"docs":[{"author_name":["Frank Herbert"],"cover_i":11481354,"title":"Dune"}]}"#
        XCTAssertEqual(ISBNLookup.parseOpenLibrary(d(json)),
                       ISBNFound(title: "Dune", author: "Frank Herbert", coverURL: "https://covers.openlibrary.org/b/id/11481354-L.jpg"))
        XCTAssertNil(ISBNLookup.parseOpenLibrary(d(#"{"numFound":0,"docs":[]}"#)))
        XCTAssertEqual(ISBNLookup.parseApple(d(apple))?.title, "Dune")
    }

    private func row(_ s: String, _ b: String, _ o: String?) -> String {
        let ord = o.map { #","ord":{"type":"literal","value":"\#($0)"}"# } ?? ""
        return #"{"sLabel":{"value":"\#(s)"},"bLabel":{"value":"\#(b)"}\#(ord)}"#
    }

    func testSeriesPicksBiggestMatchingSeries() {
        let rows = [
            row("Foundation Trilogy", "Foundation", "1"), row("Foundation Trilogy", "Foundation and Empire", "2"),
            row("Foundation Trilogy", "Second Foundation", "3"),
            row("Foundation series", "Prelude to Foundation", "1"), row("Foundation series", "Forward the Foundation", "2"),
            row("Foundation series", "Foundation", "3"), row("Foundation series", "Foundation and Empire", "4"),
            row("Foundation series", "Second Foundation", "5"), row("Foundation series", "Foundation's Edge", "6"),
            row("Foundation series", "Foundation and Earth", "7"),
            row("Foundation series", "Some Unnumbered Extra", nil),
        ].joined(separator: ",")
        let json = #"{"results":{"bindings":[\#(rows)]}}"#
        let found = SeriesLookup.parse(d(json), series: "Foundation")
        XCTAssertEqual(found?.total, 7)
        XCTAssertEqual(found?.volumes.first, SeriesVolume(number: 1, title: "Prelude to Foundation"))
        XCTAssertEqual(found?.volumes.count, 7)
        XCTAssertNil(SeriesLookup.parse(d(json), series: "Dune"))        // a different series is refused
        XCTAssertNotNil(SeriesLookup.sparql(knownTitle: "Foundation (Foundation #1)", author: "Asimov, Isaac"))
    }
}
