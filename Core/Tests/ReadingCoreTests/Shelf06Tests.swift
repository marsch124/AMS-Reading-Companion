import XCTest
@testable import ReadingCore

/// The rules of version 0.6, one small test each. Made-up books only.
final class Shelf06Tests: XCTestCase {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + Double(n) * 86_400) }   // from 1 Jan 2026
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { utc.date(from: DateComponents(year: y, month: m, day: d))! }
    private func titles(_ books: [Book]) -> [String] { books.map(\.title) }

    private func shelf() -> LibraryData {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "c", title: "Harbour Lights at Noon", author: "Jon Meer"),
        ], source: .kobo, complete: true, now: day(10))
        return data
    }

    /// Four books, Alder to Dune Grass, ids kobo:1, kobo:2, kindle:3, apple:4.
    private func four() -> LibraryData {
        var data = LibraryData()
        data.take([ImportedBook(store: .kobo, storeID: "1", title: "Alder", author: "Ada Voss", language: "sv"),
                   ImportedBook(store: .kobo, storeID: "2", title: "Birch", author: "Ada Voss", language: "en")],
                  source: .kobo, complete: true, now: day(10))
        data.take([ImportedBook(store: .kindle, storeID: "3", title: "Cedar", author: "Jon Meer", language: "de")],
                  source: .kindle, complete: true, now: day(10))
        data.take([ImportedBook(store: .apple, storeID: "4", title: "Dune Grass", author: "Jon Meer", kind: .audiobook, language: "sv")],
                  source: .apple, complete: true, now: day(10))
        return data
    }

    private struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    // MARK: 1-2 Tags

    func testTagsAreCleanedAndCounted() {
        XCTAssertEqual(LibraryData.cleanTags(["  Sea   Stories ", "sea stories", "", "   ", String(repeating: "x", count: 40)]),
                       ["Sea Stories", String(repeating: "x", count: 30)])
        var data = shelf()
        data.setTags(["Sea", "Calm"], of: "kobo:a", now: day(11))
        data.setTags(["sea"], of: "kobo:b", now: day(11))
        data.setTags(["calm", "Rare"], of: "kobo:c", now: day(11))
        XCTAssertEqual(data.allTags().map { "\($0.tag):\($0.count)" }, ["Calm:2", "Sea:2", "Rare:1"])
    }

    func testFindFindsABookByItsTag() {
        var data = shelf()
        data.setTags(["Lighthouse keeper"], of: "kobo:c", now: day(11))
        XCTAssertEqual(data.find("lighthouse").map(\.id), ["kobo:c"])
        XCTAssertEqual(data.find("keeper lighthouse").map(\.id), ["kobo:c"])
    }

    // MARK: 3-5 The filter

    func testFilterOneOfAGroupAndAllGroups() {
        var data = four()
        data.setStatus(.reading, of: "kobo:2", now: day(11))
        var f = BookFilter()
        f.stores = [.kobo, .kindle]
        XCTAssertEqual(titles(data.books(matching: f)), ["Alder", "Birch", "Cedar"])
        f.states = [.unread]
        XCTAssertEqual(titles(data.books(matching: f)), ["Alder", "Cedar"])
        f.languages = ["sv"]
        XCTAssertEqual(titles(data.books(matching: f)), ["Alder"])
        f.states = [.unread, .reading]
        f.languages = ["sv", "en"]
        XCTAssertEqual(titles(data.books(matching: f)), ["Alder", "Birch"])
    }

    func testWishesOnlyComeAlongWhenWishIsChosen() {
        var data = four()
        data.add(title: "Glass Orchard", author: "Mia Lund", store: nil, now: day(11), newID: "w1")
        XCTAssertEqual(titles(data.books(matching: BookFilter())), ["Alder", "Birch", "Cedar", "Dune Grass"])
        var f = BookFilter()
        f.states = [.wish]
        XCTAssertEqual(titles(data.books(matching: f)), ["Glass Orchard"])
        f.states = [.wish, .unread]
        XCTAssertEqual(titles(data.books(matching: f)), ["Alder", "Birch", "Cedar", "Dune Grass", "Glass Orchard"])
        f.states = [.wish, .finished]
        XCTAssertEqual(titles(data.books(matching: f)), ["Glass Orchard"])
    }

    func testFilterStarsYearsLockFreeAndTags() {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "1", title: "Alder", purchased: date(2023, 5, 1)),
            ImportedBook(store: .kobo, storeID: "2", title: "Birch", purchased: date(2024, 6, 1)),
            ImportedBook(store: .kobo, storeID: "3", title: "Cedar", lockFree: true, purchased: date(2025, 3, 1)),
            ImportedBook(store: .kobo, storeID: "4", title: "Dune Grass"),
        ], source: .kobo, complete: true, now: day(10))
        data.setRating(5, of: "kobo:1", now: day(11))
        data.setRating(3, of: "kobo:2", now: day(11))
        data.setTags(["Sea"], of: "kobo:2", now: day(11))
        func found(_ change: (inout BookFilter) -> Void) -> [String] {
            var f = BookFilter()
            change(&f)
            return titles(data.books(matching: f, calendar: utc))
        }
        XCTAssertEqual(found { $0.stars = 0 }, ["Cedar", "Dune Grass"])
        XCTAssertEqual(found { $0.stars = 4 }, ["Alder"])
        XCTAssertEqual(found { $0.stars = 3 }, ["Alder", "Birch"])
        XCTAssertEqual(found { $0.boughtYears = [2025] }, ["Cedar"])
        XCTAssertEqual(found { $0.boughtBefore = 2025 }, ["Alder", "Birch"])
        XCTAssertEqual(found { $0.boughtYears = [2025]; $0.boughtBefore = 2024 }, ["Alder", "Cedar"])
        XCTAssertEqual(found { $0.lockFree = true }, ["Cedar"])
        XCTAssertEqual(found { $0.tags = [LibraryData.tagKey("Sea")] }, ["Birch"])
        XCTAssertEqual(data.boughtYears(calendar: utc), [2025, 2024, 2023])
    }

    // MARK: 6 State

    func testStateTellsReadingAsideAndGaveUpApart() {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "1", title: "Alder"),
            ImportedBook(store: .kobo, storeID: "2", title: "Birch"),
            ImportedBook(store: .kobo, storeID: "3", title: "Cedar", progress: 0.5, lastOpened: day(0)),
            ImportedBook(store: .kobo, storeID: "4", title: "Dune Grass", progress: 0.4, lastOpened: day(200)),
            ImportedBook(store: .kobo, storeID: "5", title: "Elm"),
            ImportedBook(store: .kobo, storeID: "6", title: "Fir", finished: true, lastOpened: day(150)),
        ], source: .kobo, complete: true, now: day(210))
        data.setStatus(.reading, of: "kobo:2", now: day(211))
        data.setGaveUp(true, of: "kobo:5", now: day(211))
        data.add(title: "Glass Orchard", author: "Mia Lund", store: nil, now: day(211), newID: "w1")
        func state(_ id: String) -> ShelfState { data.state(of: data.book(id)!) }
        XCTAssertEqual(state("kobo:1"), .unread)
        XCTAssertEqual(state("kobo:2"), .reading)        // set by hand: always now
        XCTAssertEqual(state("kobo:3"), .aside)          // opened 200 days before the latest reading
        XCTAssertEqual(state("kobo:4"), .reading)
        XCTAssertEqual(state("kobo:5"), .gaveUp)
        XCTAssertEqual(state("kobo:6"), .finished)
        XCTAssertEqual(state("wish:w1"), .wish)
    }

    // MARK: 7 Encoding

    func testAFilterSurvivesEncodingAndSkipsWhatItDoesNotKnow() throws {
        var f = BookFilter()
        f.stores = [.kobo, .apple]; f.kinds = [.audiobook]; f.languages = ["sv", ""]; f.states = [.aside, .wish]
        f.stars = 4; f.boughtYears = [2024, 2025]; f.boughtBefore = 2020; f.finishedYears = [2025]; f.lockFree = true; f.tags = ["sea"]
        let back = try JSONDecoder().decode(BookFilter.self, from: JSONEncoder().encode(f))
        XCTAssertEqual(back, f)
        let json = #"{"stores":["kobo","zzz"],"states":["finished","bogus"],"languages":["sv"],"lockFree":true}"#
        let odd = try JSONDecoder().decode(BookFilter.self, from: Data(json.utf8))
        XCTAssertEqual(odd.stores, [.kobo])
        XCTAssertEqual(odd.states, [.finished])
        XCTAssertEqual(odd.languages, ["sv"])
        XCTAssertTrue(odd.lockFree)
    }

    // MARK: 8-9 Kept filters

    func testAKeptFilterIsAShelfAndCanBeRenamedAndRemoved() {
        var data = four()
        var f = BookFilter()
        f.stores = [.kobo]
        XCTAssertNil(data.keepFilter(BookFilter(), name: "Nothing", now: day(11), newID: "f0"))
        XCTAssertNil(data.keepFilter(f, name: "   ", now: day(11), newID: "f0"))
        XCTAssertTrue(data.savedFilters.isEmpty)
        XCTAssertNotNil(data.keepFilter(f, name: "  My Kobo ", now: day(11), newID: "f1"))
        XCTAssertEqual(data.shelf("saved-f1")?.title, "My Kobo · 2")
        XCTAssertEqual(data.shelf("saved-f1")?.books.count, 2)
        data.changeKeptFilter("f1", name: "Renamed", now: day(12))
        XCTAssertEqual(data.shelf("saved-f1")?.title, "Renamed · 2")
        data.removeKeptFilter("f1", now: day(13))
        XCTAssertNil(data.shelf("saved-f1"))
        XCTAssertNil(data.keptFilter(shelfID: "saved-f1"))
    }

    func testBetweenTwoDevicesTheNewerChangeOfAKeptFilterWins() {
        var base = four()
        var f = BookFilter()
        f.stores = [.kobo]
        base.keepFilter(f, name: "Mine", now: day(11), newID: "f1")
        base.keepFilter(f, name: "Other", now: day(11), newID: "f2")
        var mac = base
        var phone = base
        mac.changeKeptFilter("f1", name: "Mac", now: day(20))
        phone.changeKeptFilter("f1", name: "Phone", now: day(21))
        XCTAssertEqual(LibraryData.merged(mac, phone).keptFilter(shelfID: "saved-f1")?.name, "Phone")
        XCTAssertEqual(LibraryData.merged(phone, mac).keptFilter(shelfID: "saved-f1")?.name, "Phone")
        mac.removeKeptFilter("f2", now: day(22))
        let both = LibraryData.merged(phone, mac)
        XCTAssertNil(both.keptFilter(shelfID: "saved-f2"))
        XCTAssertEqual(both.savedFilters.first { $0.id == "f2" }?.removed, true)
        XCTAssertNil(LibraryData.merged(mac, phone).keptFilter(shelfID: "saved-f2"))
    }

    // MARK: 10-11 Choose your shelves

    private func shelvesData() -> LibraryData {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "a1", title: "Alpha One", series: "Alpha", seriesNumber: 1),
            ImportedBook(store: .kobo, storeID: "a2", title: "Alpha Two", series: "Alpha", seriesNumber: 2),
            ImportedBook(store: .kobo, storeID: "b1", title: "Beta One", series: "Beta", seriesNumber: 1),
            ImportedBook(store: .kobo, storeID: "b2", title: "Beta Two", series: "Beta", seriesNumber: 2),
            ImportedBook(store: .kobo, storeID: "r1", title: "Reeds"),
        ], source: .kobo, complete: true, now: day(10))
        data.setStatus(.reading, of: "kobo:r1", now: day(11))
        return data
    }

    func testMainShelvesFollowTheOwnersOrderAndHideHiddenOnes() {
        var data = shelvesData()
        XCTAssertEqual(data.mainShelves().map(\.id), ["reading", "unread", "series-alpha", "series-beta", "wish"])
        data.setShelves(order: ["wish", "series", "unread", "reading"], hidden: ["reading"], now: day(12))
        XCTAssertEqual(data.mainShelves().map(\.id), ["wish", "series-alpha", "series-beta", "unread"])
        var f = BookFilter()
        f.stores = [.kobo]
        data.keepFilter(f, name: "All Kobo", now: day(13), newID: "f1")     // kept after the order was set
        XCTAssertEqual(data.mainShelves().first?.id, "saved-f1")
    }

    func testShelfChoicesListEveryShelfKeyOnce() {
        var data = shelvesData()
        var f = BookFilter()
        f.stores = [.kobo]
        data.keepFilter(f, name: "All Kobo", now: day(13), newID: "f1")
        data.setShelves(order: ["wish", "wish", "bogus", "series"], hidden: ["wish"], now: day(14))
        let choices = data.shelfChoices()
        let keys = choices.map(\.key)
        XCTAssertEqual(keys.count, Set(keys).count)
        XCTAssertEqual(Set(keys), ["reading", "upnext", "saved-f1", "unread", "series", "aside", "lockfree", "audio", "twice",
                                   "finished", "gaveup", "wish"])
        XCTAssertEqual(choices.first { $0.key == "series" }?.count, 2)
        XCTAssertEqual(choices.first { $0.key == "saved-f1" }?.name, "All Kobo")
        XCTAssertEqual(choices.first { $0.key == "wish" }?.hidden, true)
        XCTAssertEqual(choices.first { $0.key == "reading" }?.hidden, false)
    }

    // MARK: 12 Surprise me

    func testSurpriseGivesOnlyANotStartedOwnedBookAndNotTheLastOne() {
        var data = four()
        data.setStatus(.reading, of: "kindle:3", now: day(11))
        data.setStatus(.finished, of: "apple:4", now: day(11))
        data.add(title: "Glass Orchard", author: "Mia Lund", store: nil, now: day(11), newID: "w1")
        for seed in UInt64(0)..<20 {
            var g = SplitMix(state: seed)
            XCTAssertTrue(["kobo:1", "kobo:2"].contains(data.surprise(using: &g)?.id ?? ""))
            var h = SplitMix(state: seed)
            XCTAssertEqual(data.surprise(not: "kobo:1", using: &h)?.id, "kobo:2")
        }
        data.setStatus(.reading, of: "kobo:2", now: day(12))
        var g = SplitMix(state: 1)
        XCTAssertEqual(data.surprise(not: "kobo:1", using: &g)?.id, "kobo:1")       // the only one left
        data.setStatus(.reading, of: "kobo:1", now: day(12))
        XCTAssertNil(data.surprise(using: &g))
    }

    // MARK: 13 Corrected books

    func testACorrectedBookKeepsItsWordsWhenTheStoreIsReadAgain() {
        var data = shelf()
        data.correct("kobo:a", title: "My Lantern", author: "A. Voss", series: nil, number: nil, now: day(11))
        let again = [ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss",
                                  series: "Store Saga", seriesNumber: 1)]
        data.take(again, source: .kobo, complete: false, now: day(12))
        XCTAssertEqual(data.book("kobo:a")?.title, "My Lantern")
        XCTAssertEqual(data.book("kobo:a")?.author, "A. Voss")
        XCTAssertNil(data.book("kobo:a")?.series)
        data.uncorrect("kobo:a", now: day(13))
        data.take(again, source: .kobo, complete: false, now: day(14))
        XCTAssertEqual(data.book("kobo:a")?.title, "The Paper Lantern")
        XCTAssertEqual(data.book("kobo:a")?.author, "Ada Voss")
        XCTAssertEqual(data.book("kobo:a")?.series, "Store Saga")
    }

    // MARK: 14 About

    func testAboutDoesNotMoveChangedAndIsAskedAboutOnlyEvery30Days() {
        var data = shelf()
        let before = data.book("kobo:a")!.changed
        data.setAbout("A tale of lamps.", of: "kobo:a", now: day(50))
        XCTAssertEqual(data.book("kobo:a")?.about, "A tale of lamps.")
        XCTAssertEqual(data.book("kobo:a")?.changed, before)
        data.setAbout(nil, of: "kobo:b", now: day(50))
        XCTAssertEqual(data.book("kobo:b")?.changed, before)
        XCTAssertNil(data.book("kobo:b")?.about)
        XCTAssertTrue(data.shouldAskAbout(data.book("kobo:c")!, now: day(50)))
        XCTAssertFalse(data.shouldAskAbout(data.book("kobo:a")!, now: day(500)))
        XCTAssertFalse(data.shouldAskAbout(data.book("kobo:b")!, now: day(60)))
        XCTAssertFalse(data.shouldAskAbout(data.book("kobo:b")!, now: day(80)))      // exactly 30 days: not yet
        XCTAssertTrue(data.shouldAskAbout(data.book("kobo:b")!, now: day(81)))

        // merged carries the words across, even when the other side holds the newer change.
        var phone = shelf()
        phone.setRating(4, of: "kobo:a", now: day(60))
        phone.setRating(2, of: "kobo:b", now: day(60))
        for merged in [LibraryData.merged(data, phone), LibraryData.merged(phone, data)] {
            XCTAssertEqual(merged.book("kobo:a")?.about, "A tale of lamps.")
            XCTAssertEqual(merged.book("kobo:a")?.rating, 4)
            XCTAssertEqual(merged.book("kobo:b")?.aboutChecked, day(50))
        }
    }

    // MARK: 15 The author's page

    func testBooksByAnAuthorAreOwnedAndWishedWishesLast() {
        var data = shelf()
        data.take([ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss",
                                series: "Lamps", seriesNumber: 1)], source: .kobo, complete: false, now: day(11))
        data.add(title: "Glass Orchard", author: "Voss, Ada", store: nil, now: day(12), newID: "w1")
        XCTAssertEqual(titles(data.books(by: "Ada Voss")), ["A Winter of Small Bridges", "The Paper Lantern", "Glass Orchard"])
        XCTAssertEqual(titles(data.books(by: "Voss, Ada")).count, 3)
        XCTAssertEqual(titles(data.books(by: "Jon Meer")), ["Harbour Lights at Noon"])
        XCTAssertTrue(data.books(by: "").isEmpty)
    }

    // MARK: 16 The series' page

    func testSeriesPartsAreOwnedWishedAndMissingInOrder() {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "1", title: "Lamps Begin", author: "Ada Voss", series: "Lamps", seriesNumber: 1),
            ImportedBook(store: .kobo, storeID: "4", title: "Lamps Burn", author: "Ada Voss", series: "Lamps", seriesNumber: 4),
        ], source: .kobo, complete: true, now: day(10))
        func look() -> [String] {
            data.seriesParts("Lamps").map { "\($0.number ?? 0):\($0.kind.rawValue):\($0.title ?? "-")" }
        }
        XCTAssertEqual(look(), ["1:owned:Lamps Begin", "2:missing:-", "3:missing:-", "4:owned:Lamps Burn"])
        data.setSeries(SeriesInfo(total: 5, volumes: [SeriesVolume(number: 2, title: "Second Light")], checked: day(11)), for: "Lamps")
        XCTAssertEqual(look(), ["1:owned:Lamps Begin", "2:missing:Second Light", "3:missing:-", "4:owned:Lamps Burn", "5:missing:-"])
        let wish = data.wishSeriesPart(series: "Lamps", number: 3, title: nil, now: day(12), newID: "w3")
        XCTAssertEqual(wish?.title, "Lamps 3")
        XCTAssertEqual(wish?.author, "Ada Voss")
        XCTAssertEqual(wish?.series, "Lamps")
        XCTAssertEqual(wish?.seriesNumber, 3)
        XCTAssertEqual(look(), ["1:owned:Lamps Begin", "2:missing:Second Light", "3:wish:Lamps 3", "4:owned:Lamps Burn", "5:missing:-"])
        XCTAssertEqual(data.seriesParts("Lamps")[2].book?.id, "wish:w3")
    }

    // MARK: 17 Cover progress

    func testCoverProgressOnlyForAStartedBookBetween1And99Percent() {
        func progress(_ status: ReadStatus, _ p: Double?, gaveUp: Bool = false) -> Double? {
            LibraryData.coverProgress(Book(id: "x", title: "X", status: status, progress: p, gaveUp: gaveUp))
        }
        XCTAssertEqual(progress(.reading, 0.5), 0.5)
        XCTAssertEqual(progress(.reading, 0.01), 0.01)
        XCTAssertEqual(progress(.reading, 0.994), 0.994)
        XCTAssertNil(progress(.reading, 0.005))
        XCTAssertNil(progress(.reading, 0.995))
        XCTAssertNil(progress(.reading, nil))
        XCTAssertNil(progress(.unread, 0.5))
        XCTAssertNil(progress(.finished, 0.5))
        XCTAssertNil(progress(.reading, 0.5, gaveUp: true))
    }

    // MARK: 18 What changed

    func testAReadReportsWhatCameAndLeftAndChangesAreRemembered() {
        var data = LibraryData()
        let first = data.take([
            ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "c", title: "Harbour Lights at Noon", author: "Jon Meer"),
        ], source: .kobo, complete: true, now: day(10))
        XCTAssertEqual(first.came.count, 3)
        XCTAssertTrue(first.left.isEmpty)
        data.noteChange(first, store: "kobo", first: true, now: day(10))
        XCTAssertTrue(data.changes.isEmpty)                                  // the very first read is not remembered

        let second = data.take([
            ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "d", title: "Glass Orchard", author: "Mia Lund"),
        ], source: .kobo, complete: true, now: day(11))
        XCTAssertEqual(second.came, ["Glass Orchard"])
        XCTAssertEqual(second.left, ["Harbour Lights at Noon"])
        data.noteChange(second, store: "kobo", first: false, now: day(11))
        XCTAssertEqual(data.changes.count, 1)
        XCTAssertEqual(data.changes.first?.came, ["Glass Orchard"])
        XCTAssertEqual(data.changes.first?.left, ["Harbour Lights at Noon"])
        XCTAssertEqual(data.changes.first?.storeName, "Kobo")

        data.noteChange(ImportSummary(), store: "kobo", first: false, now: day(12))
        XCTAssertEqual(data.changes.count, 1)                                // a read without changes is not remembered

        var more = ImportSummary()
        more.came = ["Another"]
        for n in 20..<70 { data.noteChange(more, store: "kobo", first: false, now: day(n)) }
        XCTAssertEqual(data.changes.count, ChangeEntry.kept)
        XCTAssertEqual(data.changes.first?.date, day(69))
    }

    // MARK: 19 Notes

    func testNotesAreAddedChangedRemovedAndMergedByTheNewerChange() {
        var data = shelf()
        XCTAssertNil(data.addNote(bookID: "kobo:a", text: "   ", kind: "quote", now: day(11), newID: "n0"))
        XCTAssertNil(data.addNote(bookID: "nothing", text: "Words", kind: "quote", now: day(11), newID: "n0"))
        XCTAssertTrue(data.notes.isEmpty)
        data.addNote(bookID: "kobo:a", text: " First ", kind: "thought", now: day(11), newID: "n1")
        data.addNote(bookID: "kobo:a", text: "Second", kind: "quote", page: "41", now: day(12), newID: "n2")
        XCTAssertEqual(data.notes(of: "kobo:a").map(\.id), ["n2", "n1"])         // newest first
        XCTAssertEqual(data.note("n1")?.text, "First")
        data.changeNote("n1", text: "", kind: "todo", page: nil, now: day(13))   // empty words change nothing
        XCTAssertEqual(data.note("n1")?.kind, "thought")
        data.changeNote("n1", text: "First, better", kind: "todo", page: "chapter 3", now: day(13))
        XCTAssertEqual(data.note("n1")?.text, "First, better")
        XCTAssertEqual(data.note("n1")?.kind, "todo")
        XCTAssertEqual(data.note("n1")?.page, "chapter 3")

        var mac = data
        var phone = data
        mac.changeNote("n1", text: "mac", kind: "todo", page: nil, now: day(30))
        phone.changeNote("n1", text: "phone", kind: "todo", page: nil, now: day(31))
        XCTAssertEqual(LibraryData.merged(mac, phone).note("n1")?.text, "phone")
        XCTAssertEqual(LibraryData.merged(phone, mac).note("n1")?.text, "phone")
        mac.removeNote("n2", now: day(32))
        phone.changeNote("n2", text: "late", kind: "quote", page: nil, now: day(31))
        XCTAssertNil(LibraryData.merged(mac, phone).note("n2"))
        XCTAssertNil(LibraryData.merged(phone, mac).note("n2"))
        XCTAssertEqual(LibraryData.merged(phone, mac).notes(of: "kobo:a").map(\.id), ["n1"])
        data.removeNote("n2", now: day(14))
        XCTAssertEqual(data.notes(of: "kobo:a").map(\.id), ["n1"])
    }

    // MARK: 20 Kinds

    func testKindsAreAddedRenamedAndRemovedAndANoteOfARemovedKindIsOther() {
        var data = shelf()
        XCTAssertEqual(data.noteKinds.map(\.id), ["quote", "thought", "todo", "word"])
        XCTAssertEqual(data.noteKinds, NoteKind.start)
        XCTAssertEqual(data.addKind("  Idea ", now: day(11), newID: "k1")?.colour, "green")
        XCTAssertEqual(data.addKind("Map", now: day(12), newID: "k2")?.colour, "pink")
        XCTAssertNil(data.addKind("idea", now: day(13), newID: "k3"))           // double name
        XCTAssertNil(data.addKind("Quote", now: day(13), newID: "k3"))
        XCTAssertNil(data.addKind("   ", now: day(13), newID: "k3"))
        XCTAssertEqual(data.noteKinds.count, 6)
        XCTAssertEqual(data.noteKindsChanged, day(12))
        data.renameKind("k1", to: "Big idea", now: day(14))
        XCTAssertEqual(data.kind("k1").name, "Big idea")
        data.addNote(bookID: "kobo:a", text: "Think big", kind: "k1", now: day(15), newID: "n1")
        XCTAssertEqual(data.kindsInUse().first { $0.kind.id == "k1" }?.count, 1)
        data.removeKind("k1", now: day(16))
        XCTAssertEqual(data.noteKinds.count, 5)
        XCTAssertEqual(data.kind("k1"), NoteKind.other)
        XCTAssertEqual(data.kindsInUse().last?.kind.name, "Other")
        XCTAssertEqual(data.kindsInUse().last?.count, 1)
        XCTAssertEqual(data.kindsInUse().count, 6)
    }

    // MARK: 21 Sending notes

    func testNoteTextAndNotesPage() {
        var data = shelf()
        let quote = data.addNote(bookID: "kobo:a", text: "\"Light travels slowly.\"", kind: "quote", page: "41", now: day(11), newID: "n1")!
        data.addNote(bookID: "kobo:a", text: "Second line", kind: "quote", now: day(12), newID: "n2")
        let thought = data.addNote(bookID: "kobo:a", text: "A thought\nover lines", kind: "thought", page: "chapter 3", now: day(13), newID: "n3")!
        XCTAssertEqual(data.noteText(quote), "“Light travels slowly.”\n\n— Quote, “The Paper Lantern” by Ada Voss, page 41")
        XCTAssertEqual(data.noteText(thought), "A thought\nover lines\n\n— Thought, “The Paper Lantern” by Ada Voss, chapter 3")
        let page = """
        # Notes on “The Paper Lantern”
        Ada Voss · 3 notes · 21 January 2026

        ## Quote
        > “Light travels slowly.” (page 41)

        > “Second line”

        ## Thought
        - A thought over lines (chapter 3)

        """
        XCTAssertEqual(data.notesPage(of: "kobo:a", now: day(20), calendar: utc), page)
    }

    // MARK: 22 Older and newer files

    func testAFileOfFormat3GetsTheStartKindsAndAFormat5FileIsNewer() throws {
        let old = try LibraryData.decode(Data(#"{"format":3,"books":[{"id":"kobo:a","title":"The Paper Lantern"}]}"#.utf8))
        XCTAssertEqual(old.noteKinds, NoteKind.start)
        XCTAssertTrue(old.notes.isEmpty)
        XCTAssertTrue(old.savedFilters.isEmpty)
        XCTAssertTrue(old.shelfOrder.isEmpty)
        XCTAssertTrue(old.hiddenShelves.isEmpty)
        XCTAssertTrue(old.changes.isEmpty)
        XCTAssertEqual(old.books.first?.tags, [])
        XCTAssertFalse(old.isNewer)
        XCTAssertEqual(LibraryData.currentFormat, 4)
        XCTAssertTrue(try LibraryData.decode(Data(#"{"format":5}"#.utf8)).isNewer)
        XCTAssertFalse(try LibraryData.decode(Data(#"{"format":4}"#.utf8)).isNewer)
    }

    // MARK: After the code check

    func testACorrectedBookIsStillTheSameBookForAnotherStore() {
        var data = LibraryData()
        data.take([ImportedBook(store: .kobo, storeID: "x", title: "The Tin Orchard", author: "Mara Loew")],
                  source: .kobo, complete: true, now: Date(timeIntervalSince1970: 1_767_225_600))
        data.correct("kobo:x", title: "Tin Orchard, The", author: "M. Loew", series: nil, number: nil)
        data.take([ImportedBook(store: .apple, storeID: "y", title: "The Tin Orchard", author: "Mara Loew")],
                  source: .apple, complete: true, now: Date(timeIntervalSince1970: 1_767_312_000))
        XCTAssertEqual(data.owned.count, 1)
        XCTAssertEqual(data.owned.first?.copies.count, 2)
        XCTAssertEqual(data.owned.first?.title, "Tin Orchard, The")
    }

    func testUncorrectBringsTheWordsFromBeforeBackAtOnce() {
        var data = LibraryData()
        data.take([ImportedBook(store: .kobo, storeID: "x", title: "The Tin Orchard", author: "Mara Loew", series: "Orchard Years", seriesNumber: 2)],
                  source: .kobo, complete: true, now: Date(timeIntervalSince1970: 1_767_225_600))
        data.correct("kobo:x", title: "Wrong", author: "Nobody", series: "My Own Series", number: 9)
        data.correct("kobo:x", title: "Wrong Again", author: "Nobody", series: "", number: nil)
        data.uncorrect("kobo:x")
        let book = data.book("kobo:x")
        XCTAssertEqual(book?.title, "The Tin Orchard")
        XCTAssertEqual(book?.author, "Mara Loew")
        XCTAssertEqual(book?.series, "Orchard Years")
        XCTAssertEqual(book?.seriesNumber, 2)
        XCTAssertEqual(book?.detailsByHand, false)
        XCTAssertNil(book?.storeDetails)
    }

    func testTwoAuthorsWithOneLastNameHaveTheirOwnPagesAndTheLastKindStays() {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "a", title: "Sand Year", author: "Farin Holt"),
            ImportedBook(store: .kobo, storeID: "b", title: "Glass Year", author: "Holt, Farin"),
            ImportedBook(store: .kobo, storeID: "c", title: "Stone Year", author: "Bram Holt"),
            ImportedBook(store: .kobo, storeID: "d", title: "Iron Year", author: "Holt"),
        ], source: .kobo, complete: true, now: Date(timeIntervalSince1970: 1_767_225_600))
        XCTAssertEqual(Set(data.books(by: "Farin Holt").map(\.id)), ["kobo:a", "kobo:b", "kobo:d"])
        XCTAssertEqual(Set(data.books(by: "Bram Holt").map(\.id)), ["kobo:c", "kobo:d"])
        for kind in data.noteKinds { data.removeKind(kind.id) }
        XCTAssertEqual(data.noteKinds.count, 1)
    }
}
