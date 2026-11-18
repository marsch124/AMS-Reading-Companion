import XCTest
@testable import ReadingCore

final class LibraryTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func imp(_ store: BookStore, _ id: String, _ title: String, _ author: String = "Ann Author",
                     kind: BookKind = .ebook, sample: Bool = false, lockFree: Bool = false,
                     progress: Double? = nil, finished: Bool = false,
                     series: String? = nil, number: Double? = nil, purchased: Date? = nil) -> ImportedBook {
        ImportedBook(store: store, storeID: id, title: title, author: author, kind: kind, isSample: sample,
                     lockFree: lockFree, series: series, seriesNumber: number, progress: progress, finished: finished, purchased: purchased)
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
        // "New on the shelf" and "Waiting longest" depend on today's date: left out here (see Shelf08Tests).
        let shelves = lib.shelves().filter { $0.id != "new" && $0.id != "waiting" }
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

    func testSampleShowsEveryKindOfShelf() {
        let shelves = LibraryData.sample.shelves().filter { $0.id != "new" && $0.id != "waiting" }
        XCTAssertEqual(shelves.map(\.id).filter { !$0.hasPrefix("series-") },
                       ["reading", "upnext", "saved-sample-kobo", "unread", "aside", "lockfree", "audio", "twice", "pairs", "finished", "gaveup", "wish"])
        XCTAssertEqual(shelves.filter { $0.id.hasPrefix("series-") }.count, 2)
        XCTAssertTrue(shelves.allSatisfy { !$0.books.isEmpty })
        XCTAssertEqual(shelves.first { $0.id == "series-the lantern cycle" }?.note, "3 of 5 · missing 3 and 5")
        XCTAssertTrue(LibraryData.sample.books.allSatisfy { $0.coverURL == nil })
    }

    /// A book that left a store's list for a while (a half-loaded store app) and comes back is the same book:
    /// the status the owner set by hand is still on it, and it stands on the shelf once.
    func testBookThatLeftAListAndCameBackKeepsItsStatus() {
        var data = LibraryData()
        let hill = ImportedBook(store: .kobo, storeID: "k1", title: "The Glass Hill", author: "Ina Marsh")
        let pond = ImportedBook(store: .kobo, storeID: "k2", title: "Pond Weather", author: "Ina Marsh")
        data.take([hill, pond], source: .kobo, complete: true)
        data.setStatus(.finished, of: "kobo:k1")
        data.take([pond], source: .kobo, complete: true)
        XCTAssertNil(data.book("kobo:k1"))
        data.take([hill, pond], source: .kobo, complete: true)
        XCTAssertEqual(data.book("kobo:k1")?.status, .finished)
        XCTAssertEqual(data.books.filter { $0.id == "kobo:k1" }.count, 1)
    }

    /// "Reading now" holds what was opened lately. A book started long ago stands under "Set aside",
    /// unless the owner himself said he is reading it.
    func testReadingNowLeavesOutBooksStartedLongAgo() {
        var data = LibraryData()
        let day: TimeInterval = 86_400
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        data.take([
            ImportedBook(store: .apple, storeID: "1", title: "Fresh Bread", author: "A Baker", progress: 0.4, lastOpened: base),
            ImportedBook(store: .apple, storeID: "2", title: "Old Maps", author: "B Chart", progress: 0.3, lastOpened: base - 200 * day),
            ImportedBook(store: .apple, storeID: "3", title: "Slow River", author: "C Reed", progress: 0.1, lastOpened: base - 300 * day),
        ], source: .apple, complete: true)
        data.setStatus(.reading, of: "apple:3")
        let shelves = data.shelves()
        XCTAssertEqual(Set(shelves.first { $0.id == "reading" }?.books.map(\.id) ?? []), ["apple:1", "apple:3"])
        XCTAssertEqual(shelves.first { $0.id == "aside" }?.books.map(\.id), ["apple:2"])
        XCTAssertEqual(shelves.first { $0.id == "aside" }?.title, "Set aside · 1")
        XCTAssertNil(shelves.first { $0.id == "unread" })
    }

    /// A book on the shelf that its store later marks as a sample or a built-in item leaves the shelf,
    /// even when the list is not the store's whole list (Kindle).
    func testWhatAStoreLaterMarksAsNotABookLeavesTheShelf() {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kindle, storeID: "B0REAL", title: "Harbour Lights", author: "Una Vale"),
            ImportedBook(store: .kindle, storeID: "B0DICT", title: "---------------", author: "----"),
        ], source: .kindle, complete: false)
        XCTAssertEqual(data.owned.count, 2)
        data.take([
            ImportedBook(store: .kindle, storeID: "B0REAL", title: "Harbour Lights", author: "Una Vale"),
            ImportedBook(store: .kindle, storeID: "B0DICT", title: "---------------", author: "----", isSample: true),
        ], source: .kindle, complete: false)
        XCTAssertEqual(data.owned.map(\.id), ["kindle:B0REAL"])
    }

    /// A list file without book numbers, read after the store's own list brought the same title,
    /// does not put a second copy of that store on the book.
    func testSameTitleFromTheSameStoreAgainAddsNoSecondCopy() {
        var data = LibraryData()
        data.take([ImportedBook(store: .kindle, storeID: "B0REAL", title: "Harbour Lights", author: "Una Vale")],
                  source: .kindle, complete: false)
        data.take([ImportedBook(store: .kindle, storeID: "title-harbourlights", title: "Harbour Lights: A Novel", author: "Una Vale", finished: true),
                   ImportedBook(store: .kindle, storeID: "title-saltroad", title: "Salt Road", author: "Per Lind")],
                  source: .kindle, complete: false)
        XCTAssertEqual(data.owned.count, 2)
        XCTAssertEqual(data.book("kindle:B0REAL")?.copies.count, 1)
        XCTAssertEqual(data.book("kindle:B0REAL")?.status, .finished)
    }

    // MARK: Version 0.3 rules

    private func day(_ n: Int) -> Date { t0.addingTimeInterval(Double(n) * 86_400) }

    func testUnreadHoldsOnlyNotReadBooks() {
        var lib = library([imp(.kobo, "a", "Quiet Pond", progress: 0.5), imp(.kobo, "b", "Fresh Page")])
        XCTAssertEqual(lib.shelf("unread")?.books.map(\.id), ["kobo:b"])
        lib.setStatus(.reading, of: "kobo:b", now: t0)
        XCTAssertNil(lib.shelf("unread"))
    }

    func testBoughtTwiceShelfHoldsSameKindInTwoStores() {
        var lib = library([imp(.kobo, "k1", "Tidal Maps"), imp(.kobo, "k2", "Solo Book")])
        lib.take([imp(.kindle, "A1", "Tidal Maps")], source: .kindle, complete: false, now: t0)
        XCTAssertEqual(lib.shelf("twice")?.books.map(\.title), ["Tidal Maps"])
        XCTAssertEqual(lib.shelf("twice")?.title, "Bought twice · 1")
    }

    func testGaveUpLeavesReadingAndAsideAndAnyStatusEndsIt() {
        var lib = LibraryData()
        lib.take([imp(.kobo, "a", "Dry Creek", progress: 0.4), imp(.kobo, "b", "Wet Creek", progress: 0.4)],
                 source: .kobo, complete: true, now: t0)
        lib.setGaveUp(true, of: "kobo:a", now: t0)
        XCTAssertEqual(lib.shelf("gaveup")?.books.map(\.id), ["kobo:a"])
        XCTAssertEqual(lib.shelf("gaveup")?.title, "Gave up · 1")
        XCTAssertEqual(lib.shelf("reading")?.books.map(\.id), ["kobo:b"])
        XCTAssertNil(lib.shelf("aside"))
        lib.setStatus(.reading, of: "kobo:a", now: t0)
        XCTAssertNil(lib.shelf("gaveup"))
        XCTAssertFalse(lib.book("kobo:a")!.gaveUp)
    }

    func testSeriesNoteWithAndWithoutWhatACatalogueSaid() {
        var lib = LibraryData()
        lib.take([imp(.kobo, "s1", "Lamp One", series: "Lamp Cycle", number: 1),
                  imp(.kobo, "s2", "Lamp Two", series: "Lamp Cycle", number: 2),
                  imp(.kobo, "s4", "Lamp Four", series: "Lamp Cycle", number: 4)],
                 source: .kobo, complete: false, now: t0)
        XCTAssertEqual(lib.shelf("series-lamp cycle")?.note, "3 owned · missing 3")
        lib.setSeries(SeriesInfo(total: 7, checked: t0), for: "Lamp Cycle")
        XCTAssertEqual(lib.shelf("series-lamp cycle")?.note, "3 of 7 · missing 3, 5, 6 and 7")
    }

    func testNextInSeriesFindsTheBookThenTheNameThenTheNumber() {
        var lib = LibraryData()
        lib.take([imp(.kobo, "s1", "Lamp One", series: "Lamp Cycle", number: 1),
                  imp(.kobo, "s2", "Lamp Two", series: "Lamp Cycle", number: 2),
                  imp(.kobo, "s5", "Lamp Five", series: "Lamp Cycle", number: 5)],
                 source: .kobo, complete: false, now: t0)
        let one = lib.book("kobo:s1")!, two = lib.book("kobo:s2")!, five = lib.book("kobo:s5")!
        XCTAssertEqual(lib.nextInSeries(after: one)?.owned?.id, "kobo:s2")
        XCTAssertEqual(lib.nextInSeries(after: two), SeriesNext(number: 3, title: nil, owned: nil))   // later book on shelf
        XCTAssertNil(lib.nextInSeries(after: five))                                                    // nothing known
        lib.setSeries(SeriesInfo(total: 5, volumes: [SeriesVolume(number: 3, title: "Lamp Three")], checked: t0), for: "Lamp Cycle")
        XCTAssertEqual(lib.nextInSeries(after: two), SeriesNext(number: 3, title: "Lamp Three", owned: nil))
        XCTAssertEqual(lib.nextInSeries(after: lib.book("kobo:s2")!)?.title, "Lamp Three")
        XCTAssertNil(lib.nextInSeries(after: five))                                                    // complete
    }

    func testWhatNextOrderAndNoBookTwice() {
        var lib = LibraryData()
        lib.take([imp(.kobo, "s1", "Lamp One", finished: true, series: "Lamp Cycle", number: 1, purchased: day(1)),
                  imp(.kobo, "s2", "Lamp Two", series: "Lamp Cycle", number: 2, purchased: day(2)),
                  imp(.kobo, "n", "Newest Tale", purchased: day(50)),
                  imp(.kobo, "o", "Oldest Tale", purchased: t0.addingTimeInterval(-400 * 86_400)),
                  imp(.kobo, "r", "Busy Page", progress: 0.5, purchased: day(60))],
                 source: .kobo, complete: false, now: t0)
        let next = lib.whatNext()
        XCTAssertEqual(next.map(\.book.id), ["kobo:s2", "kobo:n", "kobo:o"])   
        XCTAssertEqual(next[0].reason, "Next in Lamp Cycle, after “Lamp One”")
        XCTAssertEqual(next[1].reason, "Your newest book")
        XCTAssertTrue(next[2].reason.hasPrefix("Waiting since "))
    }

    func testRatingNoteAndCover() {
        var lib = library([imp(.kobo, "a", "Quiet Pond", "Ann Author")])
        lib.setRating(9, of: "kobo:a", now: t0)
        XCTAssertEqual(lib.book("kobo:a")?.rating, 5)
        lib.setRating(nil, of: "kobo:a", now: t0)
        XCTAssertNil(lib.book("kobo:a")?.rating)
        lib.setNote("  lovely heron scenes \n", of: "kobo:a", now: t0)
        XCTAssertEqual(lib.book("kobo:a")?.note, "lovely heron scenes")
        XCTAssertEqual(lib.find("heron").count, 1)
        lib.setNote("   ", of: "kobo:a", now: t0)
        XCTAssertNil(lib.book("kobo:a")?.note)
        lib.setCover("https://example.test/one.jpg", of: "kobo:a")
        lib.setCover("https://example.test/two.jpg", of: "kobo:a")
        XCTAssertEqual(lib.book("kobo:a")?.coverURL, "https://example.test/one.jpg")
    }

    func testShelfFilterNarrowsAndOrders() {
        var lib = library([imp(.kobo, "k1", "Beta Book", "Zed Zander"), imp(.kobo, "k2", "Alpha Book", "Yan Young")])
        lib.take([imp(.apple, "a1", "Gamma Book", "Xia Xu", kind: .audiobook)], source: .apple, complete: false, now: t0)
        let all = lib.owned
        XCTAssertEqual(ShelfFilter(store: .apple).apply(to: all).map(\.title), ["Gamma Book"])
        XCTAssertEqual(ShelfFilter(kind: .listen).apply(to: all).map(\.title), ["Gamma Book"])
        XCTAssertEqual(ShelfFilter(kind: .read).apply(to: all).count, 2)
        XCTAssertEqual(ShelfFilter(order: .title).apply(to: all).map(\.title), ["Alpha Book", "Beta Book", "Gamma Book"])
        XCTAssertEqual(ShelfFilter(order: .author).apply(to: all).map(\.title), ["Gamma Book", "Alpha Book", "Beta Book"])
        XCTAssertTrue(ShelfFilter().isPlain)
    }

    func testFormatTwoMergeKeepsNewerSeriesInfoAndFormatOneStillDecodes() throws {
        var a = LibraryData(), b = LibraryData()
        a.setSeries(SeriesInfo(total: 3, checked: day(1)), for: "Lamp Cycle")
        b.setSeries(SeriesInfo(total: 5, checked: day(2)), for: "Lamp Cycle")
        XCTAssertEqual(LibraryData.merged(a, b).seriesInfo(for: "Lamp Cycle")?.total, 5)
        XCTAssertEqual(LibraryData.merged(b, a).seriesInfo(for: "Lamp Cycle")?.total, 5)
        XCTAssertEqual(LibraryData.currentFormat, 5)
        let old = #"{"format":1,"books":[{"id":"b1","title":"Tidal Maps","added":"2026-01-01T00:00:00Z","changed":"2026-01-01T00:00:00Z"}]}"#
        let lib = try LibraryData.decode(Data(old.utf8))
        XCTAssertEqual(lib.format, 1)
        XCTAssertNil(lib.books[0].rating)
        XCTAssertNil(lib.books[0].note)
        XCTAssertFalse(lib.books[0].gaveUp)
        XCTAssertTrue(lib.series.isEmpty)
    }

    /// A cover found on one device must not beat a rating made on another: finding a cover is no "newer change",
    /// and when two copies of the shelf are joined the cover is carried over to the side that wins.
    func testACoverFoundOnOneDeviceNeverWinsOverARatingFromAnother() {
        var phone = LibraryData()
        phone.take([ImportedBook(store: .kindle, storeID: "B1", title: "Tide Tables", author: "Nora Quill")], source: .kindle, complete: false,
                   now: Date(timeIntervalSince1970: 1_790_000_000))
        var mac = phone
        mac.setRating(4, of: "kindle:B1", now: Date(timeIntervalSince1970: 1_790_000_500))
        phone.setCover("https://example.test/tide.jpg", of: "kindle:B1")
        for joined in [LibraryData.merged(phone, mac), LibraryData.merged(mac, phone)] {
            XCTAssertEqual(joined.book("kindle:B1")?.rating, 4)
            XCTAssertEqual(joined.book("kindle:B1")?.coverURL, "https://example.test/tide.jpg")
        }
    }
}
