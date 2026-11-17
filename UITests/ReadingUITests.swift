import XCTest

/// One screen test, found by identifiers: the shelf, then the search.
final class ReadingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testShelfAndSearch() {
        let app = XCUIApplication()
        var arguments = ["-sampleData"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(element(app, "shelf-list").waitForExistence(timeout: 15))
        let open = element(app, "open-search")
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(element(app, "search-field").waitForExistence(timeout: 5))
    }
}
