#if os(macOS)
import XCTest
import SQLite3
@testable import ReadingCore

final class ImporterTests: XCTestCase {
    private func tempFolder() throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("ImporterTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: u) }
        return u
    }

    private func makeDB(_ url: URL, _ sql: [String]) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        for s in sql { XCTAssertEqual(sqlite3_exec(db, s, nil, nil, nil), SQLITE_OK, s) }
    }

    func testAppleBooks() throws {
        let dir = try tempFolder()
        try makeDB(dir.appendingPathComponent("BKLibrary-1-1.sqlite"), [
            "CREATE TABLE ZBKLIBRARYASSET (Z_PK INTEGER PRIMARY KEY, ZASSETID TEXT, ZSTOREID TEXT, ZTITLE TEXT, ZAUTHOR TEXT, ZCONTENTTYPE INTEGER, ZISSAMPLE INTEGER, ZISSTOREAUDIOBOOK INTEGER, ZISFINISHED INTEGER, ZREADINGPROGRESS REAL, ZPURCHASEDATE REAL, ZPATH TEXT, ZCOVERURL TEXT, ZSERIESID TEXT, ZSEQUENCENUMBER REAL, ZSERIESCONTAINER INTEGER)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (1,'S1','900','The Tale Saga',NULL,5,0,0,0,0,0,NULL,NULL,'900',NULL,NULL)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (2,'A2','111','Tale One','Ann Author',4,0,0,1,0.5,0,NULL,'https://example.com/c.jpg','900',2,1)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (3,'A3','222','A Free Taste','Bo Writer',1,1,0,0,0,0,NULL,'http://example.com/d.jpg',NULL,NULL,NULL)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (4,'A4','','My Own Notes','',3,0,0,0,0,0,'/tmp/notes.pdf',NULL,NULL,NULL,NULL)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (5,'A5','333','Spoken Words','Cy Voice',6,0,1,0,0,0,NULL,NULL,NULL,NULL,NULL)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (6,'A6','444',NULL,'No Title',1,0,0,0,0,0,NULL,NULL,NULL,NULL,NULL)",
        ])
        let books = try AppleBooksImporter.read(folder: dir)
        XCTAssertEqual(books.count, 4)                       // series row and titleless row skipped
        let one = try XCTUnwrap(books.first { $0.title == "Tale One" })
        XCTAssertEqual(one.series, "The Tale Saga"); XCTAssertEqual(one.seriesNumber, 2)
        XCTAssertEqual(one.store, .apple); XCTAssertTrue(one.finished); XCTAssertFalse(one.lockFree)
        XCTAssertEqual(one.progress, 0.5)
        XCTAssertTrue(try XCTUnwrap(books.first { $0.title == "A Free Taste" }).isSample)
        let own = try XCTUnwrap(books.first { $0.title == "My Own Notes" })
        XCTAssertEqual(own.store, .own); XCTAssertTrue(own.lockFree); XCTAssertEqual(own.filePath, "/tmp/notes.pdf")
        XCTAssertEqual(own.kind, .pdf)
        XCTAssertEqual(try XCTUnwrap(books.first { $0.title == "Spoken Words" }).kind, .audiobook)
    }

    func testKindle() throws {
        let dir = try tempFolder()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Cache"), withIntermediateDirectories: true)
        let xml = """
        <response><add_update_list>
        <meta_data><ASIN>B000TEST01</ASIN><title>Made Up Book</title><authors><author>Doe, Jane</author><author>Doe, Jane</author></authors><purchase_date>2021-09-14T14:00:49+0000</purchase_date><cde_contenttype>EBOK</cde_contenttype><content_type>application/x-mobipocket-ebook</content_type></meta_data>
        <meta_data><ASIN>B000TEST02</ASIN><title>Sample Of Something</title><authors></authors><purchase_date></purchase_date><cde_contenttype>EBSP</cde_contenttype></meta_data>
        <meta_data><ASIN>B000TEST03</ASIN><title>My Document</title><authors></authors><cde_contenttype>PDOC</cde_contenttype></meta_data>
        </add_update_list></response>
        """
        try xml.write(to: dir.appendingPathComponent("Cache/KindleSyncMetadataCache.xml"), atomically: true, encoding: .utf8)
        let books = try KindleImporter.read(folder: dir)
        XCTAssertEqual(books.count, 3)
        let a = books[0]
        XCTAssertEqual(a.store, .kindle); XCTAssertEqual(a.storeID, "B000TEST01"); XCTAssertEqual(a.author, "Jane Doe")
        XCTAssertNotNil(a.purchased); XCTAssertFalse(a.lockFree)
        XCTAssertEqual(a.coverURL, "https://m.media-amazon.com/images/P/B000TEST01.01._SCLZZZZZZZ_.jpg")
        XCTAssertTrue(books[1].isSample)
        XCTAssertEqual(books[2].store, .own); XCTAssertTrue(books[2].lockFree)
    }

    /// Kindle's own dictionaries are not the owner's books: an entry without a purchase day, or with a title
    /// of dashes, is marked like a sample; a personal document without a purchase day is not.
    func testKindleLeavesOutBuiltInEntries() throws {
        let dir = try tempFolder()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Cache"), withIntermediateDirectories: true)
        let xml = """
        <response><add_update_list>
        <meta_data><ASIN>B000TEST11</ASIN><title>Bought Book</title><authors><author>Doe, Jane</author></authors><purchase_date>2021-09-14T14:00:49+0000</purchase_date><cde_contenttype>EBOK</cde_contenttype></meta_data>
        <meta_data><ASIN>B000TEST12</ASIN><title>Built-in Wordbook</title><authors></authors><purchase_date></purchase_date><cde_contenttype>EBOK</cde_contenttype></meta_data>
        <meta_data><ASIN>B000TEST13</ASIN><title>---------------</title><authors><author>----</author></authors><purchase_date>2022-01-09T10:00:00+0000</purchase_date><cde_contenttype>EBOK</cde_contenttype></meta_data>
        <meta_data><ASIN>B000TEST14</ASIN><title>My Document</title><authors></authors><cde_contenttype>PDOC</cde_contenttype></meta_data>
        </add_update_list></response>
        """
        try xml.write(to: dir.appendingPathComponent("Cache/KindleSyncMetadataCache.xml"), atomically: true, encoding: .utf8)
        let books = try KindleImporter.read(folder: dir)
        XCTAssertEqual(books.map(\.isSample), [false, true, true, false])
    }

    func testKobo() throws {
        let dir = try tempFolder()
        let db = dir.appendingPathComponent("Kobo.sqlite")
        try makeDB(db, [
            "CREATE TABLE content (ContentID TEXT, ContentType TEXT, BookID TEXT, Title TEXT, Attribution TEXT, ___PercentRead INTEGER, ReadStatus INTEGER, DateLastRead TEXT, Series TEXT, SeriesNumber TEXT, ImageId TEXT, MimeType TEXT, Accessibility INTEGER)",
            "INSERT INTO content VALUES ('b1','6',NULL,'Made Up Novel','Kim Writer',50,1,'2024-03-04T10:11:12Z','Made Up Series','3','img1','application/epub+zip',1)",
            "INSERT INTO content VALUES ('b1!ch1','9','b1','Chapter One',NULL,0,0,NULL,NULL,NULL,NULL,NULL,1)",
            "INSERT INTO content VALUES ('b2','6','','A Preview','Lee Pen',0,0,NULL,NULL,NULL,'img2','application/epub+zip',6)",
            "INSERT INTO content VALUES ('b3','6',NULL,'Listen Up','Max Voice',100,2,NULL,NULL,NULL,'img3','audio/mpeg',1)",
            "INSERT INTO content VALUES ('file:///mnt/onboard/mine.epub','6',NULL,'Mine','Me',0,0,NULL,NULL,NULL,NULL,'application/epub+zip',1)",
        ])
        let books = try KoboImporter.read(database: db)
        XCTAssertEqual(books.count, 4)                       // chapter row skipped
        let n = try XCTUnwrap(books.first { $0.storeID == "b1" })
        XCTAssertEqual(n.progress, 0.5); XCTAssertEqual(n.series, "Made Up Series"); XCTAssertEqual(n.seriesNumber, 3)
        XCTAssertNotNil(n.lastOpened); XCTAssertEqual(n.coverURL, "https://cdn.kobo.com/book-images/img1/353/569/90/False/cover.jpg")
        XCTAssertTrue(try XCTUnwrap(books.first { $0.storeID == "b2" }).isSample)
        let a = try XCTUnwrap(books.first { $0.storeID == "b3" })
        XCTAssertEqual(a.kind, .audiobook); XCTAssertTrue(a.finished)
        let own = try XCTUnwrap(books.first { $0.title == "Mine" })
        XCTAssertEqual(own.store, .own); XCTAssertTrue(own.lockFree); XCTAssertEqual(own.filePath, "/mnt/onboard/mine.epub")
    }

    func testMissingTablesGiveEmptyList() throws {
        let dir = try tempFolder()
        let db = dir.appendingPathComponent("Kobo.sqlite")
        try makeDB(db, ["CREATE TABLE other (x INTEGER)"])
        XCTAssertEqual(try KoboImporter.read(database: db), [])
        XCTAssertEqual(try KindleImporter.read(folder: dir), [])
    }
}
#endif
