import XCTest
@testable import ReadingCore

/// The rules of version 0.7, one small test each. Made-up books only.
final class Shelf07Tests: XCTestCase {
    private func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + n * 86_400) }   // from 1 Jan 2026
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func shelf() -> LibraryData {
        var data = LibraryData()
        data.take([ImportedBook(store: .kobo, storeID: "1", title: "Alder", author: "Ada Voss"),
                   ImportedBook(store: .kobo, storeID: "2", title: "Birch Café", author: "Jon Meer")],
                  source: .kobo, complete: true, now: day(10))
        data.take([ImportedBook(store: .apple, storeID: "9", title: "Alder", author: "Ada Voss", kind: .audiobook)],
                  source: .apple, complete: true, now: day(10))
        return data
    }

    func testReadAndListenShelfHoldsOnlyTitlesOwnedBothWays() {
        let data = shelf()
        XCTAssertEqual(data.pairs.map(\.title), ["Alder"])
        XCTAssertEqual(data.shelf("pairs")?.books.map(\.title), ["Alder"])
        XCTAssertFalse(data.pairs[0].ownedTwice, "an ebook and its audiobook are not bought twice")
        XCTAssertTrue(data.shelfChoices().contains { $0.key == "pairs" })
    }

    func testNotesAreFoundByWordBookAuthorAndKind() {
        var data = shelf()
        let birch = data.owned.first { $0.title == "Birch Café" }!.id
        let alder = data.owned.first { $0.title == "Alder" }!.id
        data.addNote(bookID: birch, text: "The harbour sleeps.", kind: "quote", page: "41", now: day(20), newID: "a")
        data.addNote(bookID: alder, text: "Ask about the harbour map.", kind: "todo", now: day(21), newID: "b")
        XCTAssertEqual(data.notes(holding: "HARBOUR").map(\.id), ["b", "a"])
        XCTAssertEqual(data.notes(holding: "cafe").map(\.id), ["a"], "found by its book's title, accents folded")
        XCTAssertEqual(data.notes(holding: "voss harbour").map(\.id), ["b"], "every word must be there")
        XCTAssertEqual(data.notes(holding: "harbour", kind: "quote").map(\.id), ["a"])
        XCTAssertEqual(data.notes(holding: "  ").count, 2)
        XCTAssertTrue(data.notes(holding: "lighthouse").isEmpty)
    }

    func testQuoteOfDayStaysAllDayAndChangesNextDay() {
        var data = shelf()
        let id = data.owned[0].id
        XCTAssertNil(data.quoteOfDay(on: day(30), calendar: utc))
        data.addNote(bookID: id, text: "Not a quote.", kind: "thought", now: day(20), newID: "t")
        XCTAssertNil(data.quoteOfDay(on: day(30), calendar: utc))
        for n in 1...3 { data.addNote(bookID: id, text: "Quote \(n)", kind: "quote", now: day(20 + Double(n)), newID: "q\(n)") }
        let morning = data.quoteOfDay(on: day(30.1), calendar: utc)
        XCTAssertEqual(morning, data.quoteOfDay(on: day(30.9), calendar: utc))
        XCTAssertNotEqual(morning, data.quoteOfDay(on: day(31.1), calendar: utc))
        let seen = Set((30..<33).compactMap { data.quoteOfDay(on: day(Double($0)), calendar: utc)?.id })
        XCTAssertEqual(seen, ["q1", "q2", "q3"], "every quote gets its day")
    }

    func testJustFinishedAsksOnlyForFreshUnratedBooks() {
        var data = shelf()
        let id = data.owned.first { $0.title == "Birch Café" }!.id
        XCTAssertNil(data.justFinished(now: day(40)))
        data.setStatus(.finished, of: id, now: day(38))
        XCTAssertEqual(data.justFinished(now: day(40))?.id, id)
        XCTAssertNil(data.justFinished(now: day(40), skipped: [id]), "Not now is respected")
        XCTAssertNil(data.justFinished(now: day(60)), "too long ago")
        data.setRating(4, of: id, now: day(40))
        XCTAssertNil(data.justFinished(now: day(40)), "stars given: nothing to ask")
    }

    func testPageOfChosenNotesNamesBookAndKind() {
        var data = shelf()
        let id = data.owned.first { $0.title == "Birch Café" }!.id
        data.addNote(bookID: id, text: "The harbour sleeps.", kind: "quote", page: "41", now: day(20), newID: "a")
        data.addNote(bookID: id, text: "Buy part two.", kind: "todo", now: day(21), newID: "b")
        let page = data.notesPage(data.notes(holding: ""), heading: "Reading notes", now: day(30), calendar: utc)
        XCTAssertTrue(page.hasPrefix("# Reading notes\n2 notes · "))
        XCTAssertTrue(page.contains("## Birch Café — Jon Meer"))
        XCTAssertTrue(page.contains("- Quote: “The harbour sleeps.” (page 41)\n- To do: Buy part two."))
    }
}
