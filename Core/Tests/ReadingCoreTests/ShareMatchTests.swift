import XCTest
@testable import ReadingCore

final class ShareMatchTests: XCTestCase {
    let shelf = [
        ShelfEntry(title: "Harbour Lights", author: "Vale, Una", stores: ["Kindle"], wish: false),
        ShelfEntry(title: "Dust", author: "Mira Holt", stores: ["Kobo"], wish: false),
        ShelfEntry(title: "The Salt Road: A Journey", author: "Ben Rowan", stores: ["Apple Books"], wish: false),
    ]

    func testPageShapesFindTheBook() {
        for page in ["Harbour Lights: A Novel eBook : Vale, Una: Amazon.com: Kindle Store",
                     "Harbour Lights eBook by Una Vale - Rakuten Kobo",
                     "\u{200E}Harbour Lights on Apple Books",
                     "Harbour Lights by Una Vale | Goodreads"] {
            XCTAssertEqual(ShareMatch.find(pageTitle: page, in: shelf).first?.title, "Harbour Lights", page)
        }
        XCTAssertEqual(ShareMatch.find(pageTitle: "Salt Road by Ben Rowan | Goodreads", in: shelf).first?.title, "The Salt Road: A Journey")
    }

    func testShortTitleNeedsTheAuthor() {
        XCTAssertTrue(ShareMatch.find(pageTitle: "Dust Storm eBook by Someone Else - Rakuten Kobo", in: shelf).isEmpty)
        XCTAssertEqual(ShareMatch.find(pageTitle: "Dust eBook by Mira Holt - Rakuten Kobo", in: shelf).count, 1)
    }

    func testUnrelatedPageFindsNothing() {
        XCTAssertTrue(ShareMatch.find(pageTitle: "Weather in Norrkoping | Forecast", in: shelf).isEmpty)
    }

    func testLikelyTitleAndAuthor() {
        XCTAssertEqual(ShareMatch.likelyTitle("Harbour Lights: A Novel eBook : Vale, Una: Amazon.com: Kindle Store"), "Harbour Lights: A Novel")
        XCTAssertEqual(ShareMatch.likelyAuthor("Harbour Lights: A Novel eBook : Vale, Una: Amazon.com: Kindle Store"), "Una Vale")
        XCTAssertEqual(ShareMatch.likelyTitle("Harbour Lights eBook by Una Vale - Rakuten Kobo"), "Harbour Lights")
        XCTAssertEqual(ShareMatch.likelyAuthor("Harbour Lights eBook by Una Vale - Rakuten Kobo"), "Una Vale")
        XCTAssertEqual(ShareMatch.likelyTitle("\u{200E}Harbour Lights on Apple Books"), "Harbour Lights")
        XCTAssertEqual(ShareMatch.likelyTitle("Harbour Lights by Una Vale | Goodreads"), "Harbour Lights")
        XCTAssertEqual(ShareMatch.likelyAuthor("Harbour Lights by Una Vale | Goodreads"), "Una Vale")
    }
}
