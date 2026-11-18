import XCTest
@testable import ReadingCore

/// "Library check": parsing LIBRIS answers, trimmed from real ones (famous books only). No network.
final class LibraryLookupTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let factfulness = """
    {"xsearch":{"from":1,"to":4,"records":61,"list":[
    {"identifier":"http://libris.kb.se/bib/21710020","title":"Factfulness","creator":"Rosling, Hans, 1948-2017","isbn":"9789127149953","type":"E-book","language":"swe"},
    {"identifier":"http://libris.kb.se/bib/n0nr8vcslw3nl222","title":"Factfulness : ti knep som hjelper deg å forstå verden","creator":"Rosling, Hans, 1948-2017","type":"book","language":"nor"},
    {"identifier":"http://libris.kb.se/bib/gqlv3tphd3jbxhll","title":"Factfulness","creator":"Rosling, Hans, 1948-2017","type":"sound recording","language":"swe"},
    {"identifier":"http://libris.kb.se/bib/x1","title":"Factfulness","creator":"Rosling, Hans, 1948-2017","type":"moving image"}]}}
    """

    func testFoundWithSeveralForms() {
        guard case .found(let f) = LibraryLookup.read(d(factfulness), title: "Factfulness", author: "Hans Rosling", now: now) else {
            return XCTFail("expected found")
        }
        XCTAssertEqual(f.forms, [.book, .ebook, .audiobook])
        XCTAssertNil(f.atHome)
        XCTAssertEqual(f.checked, now)
        XCTAssertTrue(f.link.hasPrefix("https://libris.kb.se/hitlist?"))
    }

    func testSameTitleWrongAuthorIsUnknown() {
        XCTAssertEqual(LibraryLookup.read(d(factfulness), title: "Factfulness", author: "Cal Newport", now: now), .unknown)
    }

    func testEmptyAnswerIsUnknown() {
        let empty = #"{"xsearch":{"from":1,"to":0,"records":0,"list":[]}}"#
        XCTAssertEqual(LibraryLookup.read(d(empty), title: "Zzzqx", author: "Nobody", now: now), .unknown)
    }

    func testBrokenDataIsUnreachable() {
        XCTAssertEqual(LibraryLookup.read(d("<html>busy</html>"), title: "Factfulness", author: "Rosling", now: now), .unreachable)
    }

    func testAccentsAndSubtitleFolded() {
        let json = #"{"xsearch":{"list":[{"title":"Isprinsessan : [kriminalroman]","creator":"Läckberg, Camilla, 1974-","type":"text"},{"title":"Camilla Läckberg - Isprinsessan","creator":"Grimås, Jonas","type":"moving image"}]}}"#
        let a = LibraryLookup.read(d(json), title: "ISPRINSESSAN", author: "Camilla Lackberg", now: now)
        guard case .found(let f) = a else { return XCTFail("expected found") }
        XCTAssertEqual(f.forms, [.book])
        let deep = #"{"xsearch":{"list":[{"title":"Deep work : rules for focused success","creator":"Newport, Cal","type":"book"}]}}"#
        XCTAssertNotEqual(LibraryLookup.read(d(deep), title: "Deep Work", author: "Newport, Cal", now: now), .unknown)
    }

    func testQueryHoldsOnlyTitleAuthorIsbn() {
        let byTitle = LibraryLookup.query(title: "Deep Work", author: "Cal Newport", isbn: nil)?.absoluteString ?? ""
        XCTAssertTrue(byTitle.hasPrefix("https://libris.kb.se/xsearch?query=Deep%20Work%20newport&"))
        let byIsbn = LibraryLookup.query(title: "Deep Work", author: "Cal Newport", isbn: "978-91-89043-16-9")?.absoluteString ?? ""
        XCTAssertTrue(byIsbn.contains("query=isbn:9789189043169") || byIsbn.contains("query=isbn%3A9789189043169"))
        XCTAssertFalse(byIsbn.contains("Newport"))
        XCTAssertEqual(LibraryForm.audiobook.name, "Audiobook")
    }
}
