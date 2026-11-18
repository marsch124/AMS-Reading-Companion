import XCTest
@testable import ReadingCore

/// The rules of version 0.8, one small test each. Made-up books only.
final class Shelf08Tests: XCTestCase {
    private func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + n * 86_400) }   // from 1 Jan 2026

    /// Alder (Kobo, bought day 5), Birch (Kobo, bought day 380), Cedar (Kindle, no purchase day), read on day 400.
    private func shelf() -> LibraryData {
        var data = LibraryData()
        data.take([ImportedBook(store: .kobo, storeID: "1", title: "Alder", author: "Ada Voss", purchased: day(5)),
                   ImportedBook(store: .kobo, storeID: "2", title: "Birch", author: "Ada Voss", purchased: day(380))],
                  source: .kobo, complete: true, now: day(400))
        data.take([ImportedBook(store: .kindle, storeID: "3", title: "Cedar", author: "Jon Meer")],
                  source: .kindle, complete: true, now: day(400))
        return data
    }

    func testNewOnTheShelfAndWaitingLongest() {
        let data = shelf()
        XCTAssertEqual(data.newBooks(now: day(401)).map(\.title), ["Cedar", "Birch"], "bought, else first seen, in the last 30 days")
        XCTAssertEqual(data.waitingLongest(now: day(401)).map(\.title), ["Alder"], "not started and bought a year or more ago")
        XCTAssertTrue(data.newBooks(now: day(500)).isEmpty)
    }

    func testAuthorsCountOwnedReadAndWished() {
        var data = shelf()
        data.setStatus(.finished, of: "kobo:1", now: day(401))
        _ = data.add(title: "Dune Grass", author: "Meer, Jon", store: nil, now: day(401))
        let lines = data.authors()
        XCTAssertEqual(lines.map(\.name), ["Ada Voss", "Jon Meer"])
        XCTAssertEqual(lines[0].owned, 2); XCTAssertEqual(lines[0].finished, 1); XCTAssertEqual(lines[0].unread, 1)
        XCTAssertEqual(lines[1].owned, 1); XCTAssertEqual(lines[1].wishes, 1)
    }

    func testStoreCollectionsShowAsTagsAndFilter() {
        var data = LibraryData()
        var item = ImportedBook(store: .kobo, storeID: "1", title: "Alder", author: "Ada Voss")
        item.collections = ["Sea ", "sea", "Slow read"]
        data.take([item], source: .kobo, complete: true, now: day(10))
        data.setTags(["Slow Read", "gift"], of: "kobo:1", now: day(11))
        let book = data.book("kobo:1")!
        XCTAssertEqual(book.allTags, ["Slow Read", "gift", "Sea"])
        XCTAssertEqual(book.storeTags, ["Sea"])
        var filter = BookFilter()
        filter.tags = [LibraryData.tagKey("SEA")]
        XCTAssertEqual(data.books(matching: filter).map(\.title), ["Alder"])
        item.collections = []
        data.take([item], source: .kobo, complete: true, now: day(12))
        XCTAssertEqual(data.book("kobo:1")!.allTags, ["Slow Read", "gift"], "a collection emptied in the store leaves")
        // But a list that suddenly names no collection for many books was read half-loaded: they stay.
        var many = (1...4).map { n -> ImportedBook in
            var b = ImportedBook(store: .apple, storeID: "a\(n)", title: "Book \(n)", author: "Ada Voss")
            b.collections = ["Club"]
            return b
        }
        data.take(many, source: .apple, complete: true, now: day(13))
        for i in many.indices { many[i].collections = [] }
        data.take(many, source: .apple, complete: true, now: day(14))
        XCTAssertEqual(data.book("apple:a1")!.storeTags, ["Club"])
    }

    func testPutAwayLeavesShelvesButNotTheSearch() {
        var data = shelf()
        data.addUpNext("kobo:1", now: day(401))
        data.setPutAway(true, of: ["kobo:1"], now: day(402))
        XCTAssertFalse(data.shelves().contains { $0.books.contains { $0.id == "kobo:1" } })
        XCTAssertFalse(data.upNext.contains("kobo:1"))
        XCTAssertNotNil(data.ownedMatch(title: "Alder", author: "Ada Voss"), "still owned: never buy it twice")
        XCTAssertEqual(data.putAwayBooks.map(\.title), ["Alder"])
        data.setPutAway(false, of: ["kobo:1"], now: day(403))
        XCTAssertTrue(data.owned.contains { $0.id == "kobo:1" })
    }

    func testJoinMovesCopiesNotesAndTagsAndSurvivesTheNextRead() {
        var data = shelf()
        data.take([ImportedBook(store: .apple, storeID: "9", title: "Alder: a novel of the coast, new edition", author: "A. Voss-Lind", kind: .audiobook)],
                  source: .apple, complete: true, now: day(400))
        XCTAssertEqual(data.owned.count, 4, "the app took the audiobook for another book")
        data.addNote(bookID: "apple:9", text: "Good reader.", kind: "thought", now: day(401), newID: "n")
        data.setTags(["sea"], of: "apple:9", now: day(401))
        data.setRating(4, of: "apple:9", now: day(401))
        XCTAssertTrue(data.join("apple:9", into: "kobo:1", now: day(402)))
        let book = data.book("kobo:1")!
        XCTAssertEqual(book.copies.map(\.id), ["kobo:1", "apple:9"])
        XCTAssertEqual(book.tags, ["sea"]); XCTAssertEqual(book.rating, 4)
        XCTAssertEqual(data.notes(of: "kobo:1").map(\.id), ["n"])
        XCTAssertNil(data.book("apple:9"))
        XCTAssertFalse(data.join("apple:9", into: "kobo:1", now: day(402)), "nothing left to join")
        // The store's list is read again: the copy stays on the joined book, no second book comes back.
        data.take([ImportedBook(store: .apple, storeID: "9", title: "Alder: a novel of the coast, new edition", author: "A. Voss-Lind", kind: .audiobook)],
                  source: .apple, complete: true, now: day(403))
        XCTAssertEqual(data.owned.count, 3)
        XCTAssertEqual(data.book("kobo:1")!.title, "Alder")
    }

    func testSeveralBooksAtOnce() {
        var data = shelf()
        let ids = ["kobo:1", "kobo:2"]
        data.addTag(" Holiday ", toAll: ids, now: day(401))
        data.addTag("holiday", toAll: ids, now: day(401))
        data.setStatus(.reading, ofAll: ids, now: day(401))
        data.addUpNext(all: ids + ["kobo:1"], now: day(401))
        XCTAssertEqual(ids.map { data.book($0)!.tags }, [["Holiday"], ["Holiday"]])
        XCTAssertEqual(ids.map { data.book($0)!.status }, [.reading, .reading])
        XCTAssertEqual(data.upNext.filter(ids.contains).count, Set(data.upNext.filter(ids.contains)).count)
    }

    func testMainScreenPartsAndToDoTicksTravelBetweenDevices() throws {
        var data = shelf()
        XCTAssertTrue(data.shows(.quote))
        data.setHiddenParts([.quote, .changes], now: day(401))
        XCTAssertFalse(data.shows(.quote)); XCTAssertTrue(data.shows(.notes))
        data.addNote(bookID: "kobo:1", text: "Buy part two.", kind: "todo", now: day(401), newID: "t")
        data.addNote(bookID: "kobo:1", text: "A thought.", kind: "thought", now: day(401), newID: "x")
        XCTAssertEqual(data.openTodos.map(\.id), ["t"])
        data.setDone(true, note: "t", now: day(402))
        XCTAssertTrue(data.openTodos.isEmpty)
        let back = try LibraryData.decode(data.encoded())
        XCTAssertEqual(back.format, 5)
        XCTAssertEqual(back.hiddenParts, ["quote", "changes"])
        XCTAssertEqual(back.note("t")?.done, true)
        let merged = LibraryData.merged(shelf(), back)
        XCTAssertFalse(merged.shows(.quote), "the newer choice of main-screen parts wins")
    }
}
