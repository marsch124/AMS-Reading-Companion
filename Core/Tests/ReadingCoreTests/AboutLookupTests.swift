import XCTest
@testable import ReadingCore

/// "What it is about": cleaning and parsing on made-up books. No network.
final class AboutLookupTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }
    private let long = "A lighthouse keeper finds a map inside a bottle and sets out across the grey sea."

    func testCleanTagsAndBreaks() {
        let out = AboutLookup.clean("<p>\(long)</p><p>Second <b>bold</b> part<br/>ends   here  with spaces.</p>")
        XCTAssertEqual(out, "\(long)\nSecond bold part\nends here with spaces.")
        XCTAssertFalse(out?.contains("<") ?? true)
    }

    func testCleanEntities() {
        let out = AboutLookup.clean("Tom &amp; Jerry &quot;quote&quot; it&#39;s it&apos;s &lt;ok&gt;&nbsp;fine &#233; &#xE9; and more words here.")
        XCTAssertEqual(out, "Tom & Jerry \"quote\" it's it's <ok> fine é é and more words here.")
    }

    func testCleanCollapsesBreaks() {
        let out = AboutLookup.clean("\(long)<br><br><br><br>The end of the tale is near, said the keeper.")
        XCTAssertEqual(out, "\(long)\n\nThe end of the tale is near, said the keeper.")
    }

    func testCleanCutsAtSentenceEnd() {
        let sentence = "The keeper walks along the shore. "
        let text = String(repeating: sentence, count: 100)
        let out = AboutLookup.clean(text)
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.hasSuffix("shore.…"))
        XCTAssertLessThanOrEqual(out!.count, 2001)
    }

    func testCleanTooShort() {
        XCTAssertNil(AboutLookup.clean("<p>Short blurb.</p>"))
        XCTAssertNil(AboutLookup.clean(""))
    }

    func testParseApple() {
        let json = """
        {"resultCount":2,"results":[
        {"trackName":"Other Book","artistName":"Mira Voss","description":"\(long)"},
        {"trackName":"The Glass Lighthouse","artistName":"Mira Voss","description":"<p>\(long)</p>"}]}
        """
        XCTAssertEqual(AboutLookup.parseApple(d(json), title: "The Glass Lighthouse", author: "Voss, Mira"), long)
        XCTAssertNil(AboutLookup.parseApple(d(json), title: "Unknown Tale", author: "Mira Voss"))
    }

    func testParseOpenLibrary() {
        let hits = #"{"docs":[{"key":"/works/OL1W","title":"Another","author_name":["Mira Voss"]},{"key":"/works/OL2W","title":"The Glass Lighthouse","author_name":["Mira Voss"]}]}"#
        XCTAssertEqual(AboutLookup.parseOpenLibraryKey(d(hits), title: "The Glass Lighthouse", author: "Mira Voss"), "/works/OL2W")
        XCTAssertNil(AboutLookup.parseOpenLibraryKey(d(hits), title: "The Glass Lighthouse", author: "Zed Quill"))
        XCTAssertEqual(AboutLookup.parseOpenLibraryWork(d(#"{"description":"\#(long)"}"#)), long)
        XCTAssertEqual(AboutLookup.parseOpenLibraryWork(d(#"{"description":{"type":"/type/text","value":"\#(long)"}}"#)), long)
        XCTAssertNil(AboutLookup.parseOpenLibraryWork(d(#"{"title":"x"}"#)))
    }
}
