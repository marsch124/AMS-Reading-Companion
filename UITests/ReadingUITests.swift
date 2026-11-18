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

    /// "Your reading" opens from the main screen and shows the year, then the numbers.
    func testYourReadingOpens() {
        let app = XCUIApplication()
        var arguments = ["-sampleData"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        let open = element(app, "open-year")
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        XCTAssertTrue(element(app, "year-page").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "year-goal-button").waitForExistence(timeout: 5))
    }

    // MARK: 0.6 screens

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func tap(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let found = element(app, id)
        XCTAssertTrue(found.waitForExistence(timeout: 15), "missing \(id)", file: file, line: line)
        found.tap()
    }

    private func shows(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(app, id).waitForExistence(timeout: 10), "missing \(id)", file: file, line: line)
    }

    func testFilterMenusNarrowTheBooks() {
        let app = launch([])
        tap(app, "open-filter")
        shows(app, "results-page")
        shows(app, "results-count")
        // The Store menu opens and a tick in it narrows the books down: "Clear" then shows.
        tap(app, "filter-menu-store")
        tap(app, "filter-store-kobo")
        shows(app, "filter-clear")
    }

    func testNewNoteIsSavedAndShowsInTheNotebook() {
        let app = launch([])
        tap(app, "new-note")
        shows(app, "note-page")
        let text = element(app, "note-text")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText("A few words")
        tap(app, "note-save")
        tap(app, "open-notes")
        shows(app, "notes-page")
    }

    func testAuthorAndSeriesPagesOpenFromABook() {
        let app = launch(["-show", "Ember"])
        tap(app, "book-author")
        shows(app, "author-page")
        app.navigationBars.buttons.firstMatch.tap()
        tap(app, "book-series")
        shows(app, "series-page")
    }

    func testTagsAndCorrectPagesOpen() {
        let first = launch(["-show", "Salt", "-tags"])
        shows(first, "tags-page")
        tap(first, "tags-cancel")
        first.terminate()
        let second = launch(["-show", "Salt", "-correct"])
        shows(second, "correct-page")
    }

    func testShelvesKindsAndChangesOpenFromSettings() {
        let app = launch(["-settings"])
        tap(app, "settings-shelves")
        shows(app, "shelves-page")
        tap(app, "shelves-cancel")
        tap(app, "settings-kinds")
        shows(app, "kinds-page")
        tap(app, "kinds-done")
        tap(app, "settings-changes")
        shows(app, "changes-page")
    }

    /// 0.7: the "Just finished" card and the quote of the day stand on the main screen; the notebook searches;
    /// a shelf's page turns into a wall of covers.
    func testFinishedCardNotesSearchAndCoverWall() {
        let app = launch(["-finished"])
        shows(app, "finished-card")
        shows(app, "quote-of-day")
        // "Not now" takes the card away; the next finished book without stars may then ask in its place.
        for _ in 0..<6 where element(app, "finished-skip").waitForExistence(timeout: 2) { tap(app, "finished-skip") }
        XCTAssertFalse(element(app, "finished-card").waitForExistence(timeout: 2))
        tap(app, "open-notes")
        let field = element(app, "notes-search")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("zzzz")
        shows(app, "notes-none-found")
        tap(app, "notes-done")

        let wall = launch(["-shelf", "pairs"])
        shows(wall, "shelf-all-pairs")
        tap(wall, "wall-toggle")
        shows(wall, "cover-wall")
        tap(wall, "wall-toggle")
    }

    /// 0.8: the Authors part, the main-screen switches, Select on a shelf's page, and Put away on a book's page.
    func testAuthorsSelectPutAwayAndMainScreenSwitches() {
        let authors = launch(["-authors"])
        shows(authors, "authors-list")

        let parts = launch(["-settings", "-page", "shelves"])
        shows(parts, "part-quote")

        let shelf = launch(["-shelf", "unread"])
        tap(shelf, "select-start")
        tap(shelf, "select-all")
        shows(shelf, "select-putaway")
        tap(shelf, "select-done")
        XCTAssertFalse(element(shelf, "select-putaway").waitForExistence(timeout: 2))

        let away = launch(["-settings", "-page", "putaway"])
        shows(away, "putaway-page")
    }
}
