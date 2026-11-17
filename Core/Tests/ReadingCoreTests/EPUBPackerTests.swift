import XCTest
@testable import ReadingCore

final class EPUBPackerTests: XCTestCase {
    private func makeBook() throws -> (root: URL, folder: URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("packer-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("The Paper Lantern.epub")
        try fm.createDirectory(at: folder.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appendingPathComponent("OEBPS"), withIntermediateDirectories: true)
        try Data("application/epub+zip".utf8).write(to: folder.appendingPathComponent("mimetype"))
        try Data("<container><rootfiles/></container>".utf8).write(to: folder.appendingPathComponent("META-INF/container.xml"))
        let text = String(repeating: "A lantern made of paper glowed softly in the window. ", count: 120)
        try Data("<html><body><p>\(text)</p></body></html>".utf8).write(to: folder.appendingPathComponent("OEBPS/chapter1.xhtml"))
        try Data("x".utf8).write(to: folder.appendingPathComponent(".DS_Store"))
        try Data("account".utf8).write(to: folder.appendingPathComponent("iTunesMetadata.plist"))
        return (root, folder)
    }

    func testPacksValidEPUB() throws {
        let (root, folder) = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(EPUBPacker.isFolderBook(folder))
        let out = root.appendingPathComponent("out.epub")
        try EPUBPacker.pack(folder: folder, to: out)
        let bytes = try Data(contentsOf: out)
        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        XCTAssertEqual(Array(bytes[0..<4]), [0x50, 0x4b, 0x03, 0x04])
        XCTAssertEqual(u16(8), 0, "mimetype is stored")
        XCTAssertEqual(u16(28), 0, "no extra field")
        let nameLen = u16(26)
        XCTAssertEqual(String(decoding: bytes[30..<(30 + nameLen)], as: UTF8.self), "mimetype")
        let text = String(decoding: bytes, as: UTF8.self)
        XCTAssertFalse(text.contains("DS_Store"))
        XCTAssertFalse(text.contains("iTunesMetadata"))
        XCTAssertTrue(text.contains("OEBPS/chapter1.xhtml"))
        #if os(macOS)
        func run(_ args: [String]) throws -> (Int32, String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, String(decoding: data, as: UTF8.self))
        }
        XCTAssertEqual(try run(["-t", out.path]).0, 0)
        XCTAssertEqual(try run(["-p", out.path, "mimetype"]).1, "application/epub+zip")
        #endif
    }

    func testFolderWithoutMimetypeThrows() throws {
        let (root, folder) = try makeBook()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: folder.appendingPathComponent("mimetype"))
        XCTAssertThrowsError(try EPUBPacker.pack(folder: folder, to: root.appendingPathComponent("x.epub"))) {
            XCTAssertEqual($0 as? EPUBPacker.Trouble, .noMimetype)
        }
    }
}
