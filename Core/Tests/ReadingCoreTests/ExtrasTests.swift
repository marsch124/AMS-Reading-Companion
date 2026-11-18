import XCTest
@testable import ReadingCore

/// The rules of version 0.5, one small test each. Made-up books only.
final class ExtrasTests: XCTestCase {
    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + Double(n) * 86_400) }   // from 1 Jan 2026
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func shelf() -> LibraryData {
        var data = LibraryData()
        data.take([
            ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss"),
            ImportedBook(store: .kobo, storeID: "c", title: "Harbour Lights at Noon", author: "Jon Meer"),
        ], source: .kobo, complete: true, now: day(10))
        return data
    }

    func testUpNextKeepsTheOwnersOrderAndLeadsWhatNext() {
        var data = shelf()
        data.addUpNext("kobo:c", now: day(11))
        data.addUpNext("kobo:a", now: day(11))
        data.addUpNext("kobo:a", now: day(12))                       // twice: still once
        XCTAssertEqual(data.upNextBooks.map(\.id), ["kobo:c", "kobo:a"])
        XCTAssertEqual(data.shelf("upnext")?.books.map(\.id), ["kobo:c", "kobo:a"])
        XCTAssertEqual(data.whatNext().first?.book.id, "kobo:c")
        XCTAssertEqual(data.whatNext().first?.reason, "First on your Up next list")
        data.setUpNext(["kobo:a", "kobo:c", "nothing"], now: day(13))
        XCTAssertEqual(data.upNext, ["kobo:a", "kobo:c"])
    }

    func testAStartedBookLeavesUpNext() {
        var data = shelf()
        data.addUpNext("kobo:a", now: day(11))
        data.addUpNext("kobo:b", now: day(11))
        data.setStatus(.reading, of: "kobo:a", now: day(12))
        XCTAssertEqual(data.upNextBooks.map(\.id), ["kobo:b"])
        XCTAssertFalse(data.canBeUpNext(data.book("kobo:a")!))
    }

    func testTheNewerUpNextListWinsWhole() {
        var mac = shelf()
        var phone = mac
        mac.setUpNext(["kobo:a"], now: day(20))
        phone.setUpNext(["kobo:b", "kobo:c"], now: day(21))
        XCTAssertEqual(LibraryData.merged(mac, phone).upNext, ["kobo:b", "kobo:c"])
        XCTAssertEqual(LibraryData.merged(phone, mac).upNext, ["kobo:b", "kobo:c"])
    }

    func testFinishingSetsTheDayAndUnfinishingClearsIt() {
        var data = shelf()
        data.setStatus(.finished, of: "kobo:a", now: day(40))
        XCTAssertEqual(data.book("kobo:a")?.finishedDay, day(40))
        data.setFinishedDay(day(30), of: "kobo:a", now: day(41))
        XCTAssertEqual(data.book("kobo:a")?.finishedDay, day(30))
        data.setStatus(.reading, of: "kobo:a", now: day(42))
        XCTAssertNil(data.book("kobo:a")?.finished)
        XCTAssertNil(data.book("kobo:a")?.finishedDay)
    }

    func testAStoreFinishCountsOnTheDayItWasLastOpen() {
        var data = shelf()
        data.take([ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss",
                                finished: true, lastOpened: day(25))], source: .kobo, complete: false, now: day(50))
        XCTAssertEqual(data.book("kobo:a")?.finishedDay, day(25))
    }

    func testYearsAndGoal() {
        var data = shelf()
        data.setStatus(.finished, of: "kobo:a", now: day(40))            // 2026
        data.setStatus(.finished, of: "kobo:b", now: day(-200))          // 2025
        data.setGoal(12, year: 2025, now: day(1))
        let years = data.readingYears(now: day(400), calendar: utc)      // "now" is in 2027
        XCTAssertEqual(years.map(\.year), [2027, 2026, 2025])
        XCTAssertEqual(years.map(\.books.count), [0, 1, 1])
        XCTAssertEqual(years.map(\.goal), [12, 12, 12])                  // a goal holds for the years after
        XCTAssertNil(data.goal(year: 2024))
        data.setGoal(nil, year: 2027, now: day(2))
        XCTAssertNil(data.goal(year: 2027))
        XCTAssertEqual(data.goal(year: 2026), 12)
    }

    func testGoalLine() {
        // 1 July 2026 is day 182 of 365: half of 24 is 11 (rounded down).
        let july = day(181)
        XCTAssertEqual(LibraryData.goalLine(finished: 8, goal: 24, year: 2026, now: july, calendar: utc), "8 of 24 · 3 behind")
        XCTAssertEqual(LibraryData.goalLine(finished: 11, goal: 24, year: 2026, now: july, calendar: utc), "11 of 24 · on track")
        XCTAssertEqual(LibraryData.goalLine(finished: 13, goal: 24, year: 2026, now: july, calendar: utc), "13 of 24 · 2 ahead")
        XCTAssertEqual(LibraryData.goalLine(finished: 24, goal: 24, year: 2026, now: july, calendar: utc), "24 of 24 · goal reached")
        XCTAssertEqual(LibraryData.goalLine(finished: 8, goal: 24, year: 2025, now: july, calendar: utc), "8 of 24")
    }

    func testAStoresLanguageIsTakenButNeverCountsAsAChange() {
        var data = shelf()
        let before = data.book("kobo:a")!.changed
        data.take([ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss", language: "sv")],
                  source: .kobo, complete: false, now: day(60))
        XCTAssertEqual(data.book("kobo:a")?.language, "sv")
        XCTAssertEqual(data.book("kobo:a")?.changed, before)
    }

    func testALanguageSetByHandStays() {
        var data = shelf()
        data.setLanguage("de", of: "kobo:a", now: day(61))
        data.take([ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss", language: "sv")],
                  source: .kobo, complete: false, now: day(62))
        XCTAssertEqual(data.book("kobo:a")?.language, "de")
        let only = ShelfFilter(language: "de").apply(to: data.owned)
        XCTAssertEqual(only.map(\.id), ["kobo:a"])
    }

    func testASeriesTotalTypedByHandStays() {
        var data = shelf()
        data.setSeriesTotal(7, for: "Tide Books", now: day(70))
        data.setSeries(SeriesInfo(total: 5, volumes: [SeriesVolume(number: 1, title: "One")], checked: day(71)), for: "Tide Books")
        XCTAssertEqual(data.seriesInfo(for: "Tide Books")?.total, 7)
        XCTAssertEqual(data.seriesInfo(for: "Tide Books")?.volumes.count, 1)
        data.setSeriesTotal(nil, for: "Tide Books", now: day(72))
        XCTAssertNil(data.seriesInfo(for: "Tide Books")?.total)
        data.setSeries(SeriesInfo(total: 5, checked: day(73)), for: "Tide Books")
        XCTAssertEqual(data.seriesInfo(for: "Tide Books")?.total, 5)
    }

    func testATypedSeriesTotalSurvivesALaterLookupOnAnotherDevice() {
        var mac = shelf()
        var phone = mac
        phone.setSeriesTotal(7, for: "Tide Books", now: day(70))
        mac.setSeries(SeriesInfo(total: 5, checked: day(75)), for: "Tide Books")
        XCTAssertEqual(LibraryData.merged(mac, phone).seriesInfo(for: "Tide Books")?.total, 7)
        XCTAssertEqual(LibraryData.merged(phone, mac).seriesInfo(for: "Tide Books")?.total, 7)
    }

    func testTidyFixesOldFinishingDaysAndClearsStartedBooksFromUpNext() {
        var data = shelf()
        data.addUpNext("kobo:b", now: day(11))
        // A store saw book b started, and book a was finished before the day was kept.
        data.take([ImportedBook(store: .kobo, storeID: "b", title: "A Winter of Small Bridges", author: "Ada Voss", progress: 0.3),
                   ImportedBook(store: .kobo, storeID: "a", title: "The Paper Lantern", author: "Ada Voss", finished: true, lastOpened: day(25))],
                  source: .kobo, complete: false, now: day(50))
        if let i = data.books.firstIndex(where: { $0.id == "kobo:a" }) { data.books[i].finished = nil }
        let changed = data.book("kobo:a")!.changed
        data.tidy(now: day(51))
        XCTAssertEqual(data.upNext, [])
        XCTAssertEqual(data.book("kobo:a")?.finished, day(25))
        XCTAssertEqual(data.book("kobo:a")?.changed, changed)
    }

    func testNumbersCountTheSampleShelf() {
        let n = LibraryData.sample.numbers(calendar: utc)
        XCTAssertEqual(n.owned, 17)
        XCTAssertEqual(n.wishes, 3)
        XCTAssertEqual(n.stores.first?.name, "Kobo")
        XCTAssertEqual(n.reading.map(\.count).reduce(0, +), 17)          // every owned book stands in exactly one line
        XCTAssertEqual(n.finishedByYear.first?.name, "2026")
        XCTAssertEqual(n.rated, 2)
        XCTAssertEqual(n.meanStars, 4.5)
    }

    func testTheListAsATable() {
        var data = shelf()
        data.setNote("Good, \"really\" good", of: "kobo:a", now: day(80))
        let lines = data.listTable().components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], LibraryData.listColumns.joined(separator: ","))
        XCTAssertEqual(lines.count, 5)                                    // heading, three books, the empty end
        XCTAssertTrue(lines.contains { $0.hasPrefix("The Paper Lantern,Ada Voss,") && $0.contains("\"Good, \"\"really\"\" good\"") })
    }

    func testAFileFromVersion04StillOpens() throws {
        let old = #"{"format":2,"books":[{"id":"kobo:a","title":"The Paper Lantern","copies":[{"store":"kobo","storeID":"a"}]}],"series":{"tide":{"total":3,"volumes":[],"checked":"2026-01-01T00:00:00Z"}}}"#
        let data = try LibraryData.decode(Data(old.utf8))
        XCTAssertEqual(data.books.count, 1)
        XCTAssertEqual(data.upNext, [])
        XCTAssertNil(data.books[0].language)
        XCTAssertEqual(data.series["tide"]?.byHand, false)
        XCTAssertFalse(data.isNewer)
        XCTAssertEqual(LibraryData.currentFormat, 4)
    }
}
