import ReadingCore
import SwiftUI
import UniformTypeIdentifiers

/// The shelf list as a file the owner saves: a PDF or a comma-separated table.
struct ShelfListFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.pdf, .commaSeparatedText] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    /// "My books 2026-11-17" for today.
    static func defaultName(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "yyyy-MM-dd"
        return "My books " + f.string(from: now)
    }

    static func pdf(_ library: LibraryData) -> ShelfListFile {
        ShelfListFile(data: ShelfListPDF.make(library))
    }

    /// UTF-8 with a byte-order mark so Excel reads å, ä and ö right.
    static func table(_ library: LibraryData) -> ShelfListFile {
        ShelfListFile(data: Data([0xEF, 0xBB, 0xBF]) + Data(library.listTable().utf8))
    }
}
