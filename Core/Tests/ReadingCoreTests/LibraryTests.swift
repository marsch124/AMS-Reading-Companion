import XCTest
@testable import ReadingCore

final class LibraryTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func imp(_ store: BookStore, _ id: String, _ title: String, _ author: String = "Ann Author",
                     kind: BookKind = .ebook, sample: Bool = false, lockFree: Bool = false,
                     progress: Double? = nil, finished: Bool = false,
                     series: String? = nil, number: Double? = nil) -> ImportedBook {
        ImportedBook(store: store, storeID: id, title: title, author: author, kind: kind, isSample: sample,
                     lockFree: lockFree, series: series, seriesNumber: number, progress: progress, finished: finished)
    }

    private func library(_ items: [ImportedBook], source: CopySource = .kobo) -> LibraryData {
        var lib = LibraryData()
        lib.take(items, source: source, complete: true, now: t0)
        return lib
    }

    func testSameTitleFromTwoStoresIsOneBookOwnedTwice() {
        var lib = library([imp(.kobo, "k1", "Tidal Maps")])
        lib.take([imp(.kindle, "A1", "Tidal Maps")], source: .kindle, complete: false, now: t0)
        XCTAssertEqual(lib.shown.count, 1)
        XCTAssertEqual(lib.shown[0].copies.count, 2)
        XCTAssertTrue(lib.shown[0].ownedTwice)
    }

    func testEbookPlusAudiobookIsNotOwnedTwice() {
        var lib = library([imp(.kobo, "k1", "Tidal Maps")])
        lib.take([imp(.apple, "a1", "Tidal Maps", kind: .audiobook)], source: .apple, complete: false, now: t0)
        XCTAssertEqual(lib.shown.count, 1)
        XCTAssertFalse(lib.shown[0].ownedTwice)
    }

    func testMatchingRules() {
        XCTAssertTrue(BookMatch.same(title: "Dune", author: "Herbert, Frank", title: "Dune", author: "Frank Herbert"))
        XCTAssertTrue(BookMatch.same(title: "The Salt Road: A Novel", author: "Ann Author", title: "Salt Road", author: "Ann Author"))
        XCTAssertFalse(BookMatch.same(title: "Salt Road", author: "Ann Author", title: "Salt Road", author: "Bo Writer"))
    }

    func testSamplesAreLeftOut() {
        var lib = LibraryData()
        let s = lib.take([imp(.apple, "a1", "A Free Taste", sample: true), imp(.apple, "a2", "Real Book")],
                         source: .apple, complete: true, now: t0)
        XCTAssertEqual(lib.shown.map(\.title), ["Real Book"])
        XCTAssertEqual(s.samples, 1)
    }

    func testCompleteListRemovesWhatLeftTheStore() {
        var lib = library([imp(.kobo, "k1", "One Book"), imp(.kobo, "k2", "Two Book")])
        let s = lib.take([imp(.kobo, "k1", "One Book")], source: .kobo, complete: true, now: t0)
        XCTAssertEqual(lib.shown.map(\.title), ["One Book"])
        XCTAssertEqual(s.removed, 1)
    }

    func testEmptyListRemovesNothing() {
        var lib = library([imp(.kobo, "k1", "One Book")])
        lib.take([], source: .kobo, complete: true, now: t0)
        XCTAssertEqual(lib.shown.count, 1)
    }

    func testIncompleteListRemovesNothing() {
        var lib = library([imp(.kobo, "k1", "One Book"), imp(.kobo, "k2", "Two Book")])
        lib.take([imp(.kobo, "k1", "One Book")], source: .kobo, complete: false, now: t0)
        XCTAssertEqual(lib.shown.count, 2)
    }

    func testStatusByHandSurvivesAndUntouchedFollowsTheStore() {
        var lib = library([imp(.kobo, "k1", "Hand Book", progress: 0), imp(.kobo, "k2", "Store Book", progress: 0)])
        lib.setStatus(.unread, of: "kobo:k1", now: t0)
        lib.take([imp(.kobo, "k1", "Hand Book", progress: 0.5), imp(.kobo, "k2", "Store Book", progress: 0.5)],
                 source: .kobo, complete: true, now: t0)
        XCTAssertEqual(lib.book("kobo:k1")?.status, .unread)
        XCTAssertEqual(lib.book("kobo:k2")?.status, .reading)
    }

    func testAWishThatTurnsUpInAStoreStopsBeingAWishAndKeepsItsId() {
        var lib = LibraryData()
        let wished = lib.add(title: "Glass Orchard", author: "Ann Author", store: nil, now: t0, newID: "w1")
        lib.take([imp(.kobo, "k1", "Glass Orchard")], source: .kobo, complete: true, now: t0)
        XCTAssertEqual(lib.shown.count, 1)
        XCTAssertEqual(lib.shown[0].id, wished?.id)
        XCTAssertFalse(lib.shown[0].wish)
        XCTAssertEqual(lib.shown[0].copies.count, 1)
    }

    func testAHandAddedKindleBookIsReplacedNotDoubled() {
        var lib = LibraryData()
        lib.add(title: "Glass Orchard", author: "Ann Author", store: .kindle, now: t0, newID: "h1")
        lib.take([imp(.kindle, "B0REAL", "Glass Orchard")], source: .kindle, complete: false, now: t0)
        XCTAssertEqual(lib.shown.count, 1)
        XCTAssertEqual(lib.shown[0].copies.map(\.storeID), ["B0REAL"])
    }

    func testABookRemovedByHandStaysRemoved() {
        var lib = library([imp(.kindle, "B1", "Glass Orchard")], source: .kindle)
        lib.remove("kindle:B1", now: t0)
        XCTAssertTrue(lib.shown.isEmpty)
        lib.take([imp(.kindle, "B1", "Glass Orchard")], source: .kindle, complete: false, now: t0)
        XCTAssertTrue(lib.shown.isEmpty)
    }

    func testAnAppleBooksBookCannotBeRemoved() {
        let lib = library([imp(.apple, "a1", "Glass Orchard")], source: .apple)
        XCTAssertFalse(lib.canRemove(lib.shown[0]))
        let kindle = library([imp(.kindle, "B1", "Glass Orchard")], source: .kindle)
        XCTAssertTrue(kindle.canRemove(kindle.shown[0]))
    }

    func testShelvesComeInOrderWithTheSeriesNote() {
        var lib = LibraryData()
        lib.take([imp(.kobo, "r", "Reading One", progress: 0.5),
                  imp(.kobo, "u", "Unread One"),
                  imp(.kobo, "s1", "Lamp One", series: "The Lamp Cycle", number: 1),
                  imp(.kobo, "s2", "Lamp Two", series: "The Lamp Cycle", number: 2),
                  imp(.kobo, "s4", "Lamp Four", series: "The Lamp Cycle", number: 4),
                  imp(.own, "f", "Own File", lockFree: true),
                  imp(.apple, "au", "Audio One", kind: .audiobook),
                  imp(.kobo, "d", "Done One", finished: true)],
                 source: .kobo, complete: false, now: t0)
        lib.add(title: "Wished One", author: "Bo Writer", store: nil, now: t0, newID: "w")
        let shelves = lib.shelves()
        XCTAssertEqual(shelves.map(\.id), ["reading", "unread", "series-the lamp cycle", "lockfree", "audio", "finished", "wish"])
        XCTAssertEqual(shelves[2].note, "3 owned · missing 3")
    }

    func testMergeKeepsTheNewerChangeAndABookOnlyOneSideHas() {
        let old = Book(id: "b1", title: "Old Title", added: t0, changed: t0)
        var new = old; new.title = "New Title"; new.changed = t0.addingTimeInterval(60)
        let onlyB = Book(id: "b2", title: "Only B", added: t0, changed: t0)
        let merged = LibraryData.merged(LibraryData(books: [new]), LibraryData(books: [old, onlyB]))
        XCTAssertEqual(merged.book("b1")?.title, "New Title")
        XCTAssertNotNil(merged.book("b2"))
        let flipped = LibraryData.merged(LibraryData(books: [old, onlyB]), LibraryData(books: [new]))
        XCTAssertEqual(flipped.book("b1")?.title, "New Title")
    }

    func testDecodingToleratesAnExtraFieldAndAnUnknownStore() throws {
        let json = """
        {"format":1,"future":true,"books":[{"id":"b1","title":"Tidal Maps","author":"Ann Author","newThing":42,
         "added":"2026-01-01T00:00:00Z","changed":"2026-01-01T00:00:00Z",
         "copies":[{"store":"kobo","storeID":"k1","kind":"ebook","source":"kobo","extra":1},
                   {"store":"gutenberg","storeID":"g1","kind":"ebook","source":"file"}]}]}
        """
        let lib = try LibraryData.decode(Data(json.utf8))
        XCTAssertEqual(lib.books.count, 1)
        XCTAssertEqual(lib.books[0].copies.map(\.storeID), ["k1"])
    }

    func testFindNeedsEveryTypedWord() {
        let lib = library([imp(.kobo, "k1", "Dune Harbour", "Frank Herbert")])
        XCTAssertEqual(lib.find("frank dune").count, 1)
        XCTAssertTrue(lib.find("frank zebra").isEmpty)
    }

    // MARK: Kindle list file

    func testKindleListJSON() {
        let json = """
        [{"title":"Glass Orchard","author":"Ann Author","asin":"B0ABC12345","purchased":"March 3, 2024"},
         {"Title":"No Number Book","authors":["Bo Writer","Cy Voice"],"date":"2024-05-01T10:00:00Z"},
         {"author":"Nobody"},
         {"title":"Milli Book","ASIN":"B0MILLI","acquired":1709460000000}]
        """
        let books = KindleListFile.parse(Data(json.utf8))
        XCTAssertEqual(books.map(\.title), ["Glass Orchard", "No Number Book", "Milli Book"])
        XCTAssertEqual(books[0].storeID, "B0ABC12345")
        XCTAssertEqual(books[0].coverURL, "https://m.media-amazon.com/images/P/B0ABC12345.01._SCLZZZZZZZ_.jpg")
        XCTAssertNotNil(books[0].purchased)
        XCTAssertEqual(books[1].storeID, "title-nonumberbook")
        XCTAssertNil(books[1].coverURL)
        XCTAssertEqual(books[1].author, "Bo Writer, Cy Voice")
        XCTAssertEqual(books[2].purchased, Date(timeIntervalSince1970: 1_709_460_000))
        XCTAssertTrue(books.allSatisfy { $0.store == .kindle && $0.kind == .ebook })
        XCTAssertTrue(KindleListFile.parse(Data("not a list at all".utf8)).isEmpty)
        XCTAssertTrue(KindleListFile.parse(Data()).isEmpty)
    }

    func testKindleListCSV() {
        let csv = "Book Title;Author Name;ASIN;Purchase Date\n\"Glass; Orchard\";\"Author, Ann\";B0ABC12345;\"March 3, 2024\"\nNo Number Book;Bo Writer;;2024-05-01\n;Nobody;B0X;2024-01-01\n"
        let books = KindleListFile.parse(Data(csv.utf8))
        XCTAssertEqual(books.map(\.title), ["Glass; Orchard", "No Number Book"])
        XCTAssertEqual(books[0].author, "Author, Ann")
        XCTAssertEqual(books[0].storeID, "B0ABC12345")
        XCTAssertNotNil(books[0].purchased)
        XCTAssertEqual(books[1].storeID, "title-nonumberbook")
        let tabs = "title\tasin\nTabbed Book\tB0TAB\n"
        XCTAssertEqual(KindleListFile.parse(Data(tabs.utf8)).first?.storeID, "B0TAB")
    }

    // MARK: Sample

    func testSampleShowsAllSevenKindsOfShelf() {
        let shelves = LibraryData.sample.shelves()
        XCTAssertEqual(shelves.map(\.id).filter { !$0.hasPrefix("series-") },
                       ["reading", "unread", "lockfree", "audio", "finished", "wish"])
        XCTAssertEqual(shelves.filter { $0.id.hasPrefix("series-") }.count, 2)
        XCTAssertTrue(shelves.allSatisfy { !$0.books.isEmpty })
        XCTAssertEqual(shelves.first { $0.id == "series-the lantern cycle" }?.note, "3 owned · missing 3")
        XCTAssertTrue(LibraryData.sample.books.allSatisfy { $0.coverURL == nil })
    }
}
