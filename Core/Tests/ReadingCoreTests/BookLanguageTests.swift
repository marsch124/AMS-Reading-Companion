import XCTest
@testable import ReadingCore

final class BookLanguageTests: XCTestCase {
    func testCode() {
        XCTAssertEqual(BookLanguage.code("sv-SE"), "sv")
        XCTAssertEqual(BookLanguage.code("en_US"), "en")
        XCTAssertEqual(BookLanguage.code("swe"), "sv")
        XCTAssertEqual(BookLanguage.code("Swedish"), "sv")
        XCTAssertEqual(BookLanguage.code(" DE "), "de")
        XCTAssertNil(BookLanguage.code(""))
        XCTAssertNil(BookLanguage.code(nil))
        XCTAssertNil(BookLanguage.code("xyzzy"))
    }

    func testName() {
        XCTAssertEqual(BookLanguage.name("sv"), "Swedish")
        XCTAssertEqual(BookLanguage.name("de"), "German")
        XCTAssertEqual(BookLanguage.name("en"), "English")
        XCTAssertEqual(BookLanguage.name("da"), "Danish")
    }

    func testGuess() {
        let sv = ["Den försvunna trädgården vid sjön", "Hemligheten i det gamla huset", "Resan genom natten och mörkret",
                  "Pojken som ville flyga över havet", "Ett år på landet", "Flickan med de blå skorna", "Sommarens sista dag på ön",
                  "Gåtan i skogen"]
        let de = ["Das Geheimnis des alten Hauses am See", "Die Reise durch die lange Nacht", "Der Junge der über das Meer fliegen wollte",
                  "Ein Jahr auf dem Land", "Das Mädchen mit den blauen Schuhen", "Der letzte Sommertag auf der Insel", "Die Straße"]
        let en = ["The Secret of the Old House by the Lake", "A Journey Through the Long Night", "The Boy Who Wanted to Fly Over the Sea",
                  "One Year in the Country", "The Girl with the Blue Shoes", "The Last Summer Day on the Island", "Beginner's Guide to Gardening"]
        var right = 0, wrong = 0, none = 0
        for (exp, list) in [("sv", sv), ("de", de), ("en", en)] {
            for t in list {
                let g = BookLanguage.guess(title: t)
                if g == exp { right += 1 } else if g == nil { none += 1 } else { wrong += 1; print("WRONG", t, g!) }
            }
        }
        print("GUESS right \(right) wrong \(wrong) nil \(none)")
        XCTAssertEqual(wrong, 0)
        XCTAssertGreaterThanOrEqual(right, 12)
        XCTAssertNil(BookLanguage.guess(title: "Dune"))
        XCTAssertNil(BookLanguage.guess(title: ""))
        XCTAssertEqual(BookLanguage.guess(title: "Å"), "sv")
        XCTAssertEqual(BookLanguage.guess(title: "Maß"), "de")
    }
}
