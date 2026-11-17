import XCTest
@testable import ReadingCore

final class KindlePDFTextTests: XCTestCase {
    let sample = """
    Amazon.com: Manage Your Content and Devices
    2026-11-17, 14:57
    Go
    Showing 1 to 25 of 33 items
    Harbour Lights &amp; Other Stories Volume II
    Una Vale
    Acquired on September 14, 2021
    In 4 Devices

    Shared with Robin Example
    Deliver or remove from device
    Delete
    More actions

    The Slow Kitchen Cookbook: 100+ Recipes
    Deliver or remove from device
    Per Lind
    Acquired on December 8, 2020
    Shared with Robin Example

    Summary: The Long Week: Review
    Tidewater Publishing
    Acquired on July 1, 2020
    In 1 Device
    https://www.amazon.com/hz/mycd/digital-console/contentlist/booksAll/dateDsc/
    Page 1 of 4
    Amazon.com: Manage Your Content and Devices
    In 1 Device
    READ
    2026-11-17, 14:57
    Delete

    The Paper Orchard: A Thriller
    Deliver or remove from device
    Kit Marlow
    Acquired on April 25, 2020
    1 2
    Customer Service About Amazon
    """

    func testLooksRightAndCounts() {
        XCTAssertTrue(KindlePDFText.looksRight(sample))
        XCTAssertFalse(KindlePDFText.looksRight("Just a recipe\nwith eggs"))
        XCTAssertEqual(KindlePDFText.counts(sample)?.shown, 25)
        XCTAssertEqual(KindlePDFText.counts(sample)?.total, 33)
        XCTAssertNil(KindlePDFText.counts("nothing"))
    }

    func testBooksAndNoise() {
        let books = KindlePDFText.parse(sample)
        XCTAssertEqual(books.map(\.title), ["Harbour Lights & Other Stories Volume II",
                                            "The Slow Kitchen Cookbook: 100+ Recipes",
                                            "Summary: The Long Week: Review", "The Paper Orchard: A Thriller"])
        XCTAssertEqual(books.map(\.author), ["Una Vale", "Per Lind", "Tidewater Publishing", "Kit Marlow"])
        XCTAssertEqual(books[0].storeID, "title-harbourlightsotherstoriesvolumeii")
    }

    func testReadAcrossPageBreak() {
        let books = KindlePDFText.parse(sample)
        XCTAssertEqual(books.map(\.finished), [false, false, true, false])
    }

    func testDateIsNoonUTC() {
        let d = KindlePDFText.parse(sample)[0].purchased
        XCTAssertEqual(d, ISO8601DateFormatter().date(from: "2021-09-14T12:00:00Z"))
    }

    func testDuplicatesAndRubbish() {
        let twice = sample + "\n" + sample
        XCTAssertEqual(KindlePDFText.parse(twice).count, 4)
        XCTAssertTrue(KindlePDFText.parse("%%% rubbish \u{0}").isEmpty)
        XCTAssertTrue(KindlePDFText.parse("").isEmpty)
    }
}
