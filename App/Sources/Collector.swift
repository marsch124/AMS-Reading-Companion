import Foundation
import ReadingCore

/// What one store's list gave on the Mac: its books, or a plain line saying why there are none.
struct StoreRead: Sendable {
    var books: [ImportedBook] = []
    var trouble: String?
}

/// Reads the three stores' book lists from their apps on this Mac. Only lists: no book is opened or changed.
/// iPhone and iPad cannot do this; they get the shelf through iCloud.
enum Collector {
    /// The real home folder (inside the Mac's sandbox `NSHomeDirectory()` is the app's own box).
    static var home: URL {
        #if os(macOS)
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        #endif
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    #if os(macOS)
    static func readApple() -> StoreRead {
        let folder = home.appendingPathComponent("Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return StoreRead(trouble: "Apple Books has no list on this Mac. Open Books once.")
        }
        do {
            let books = try AppleBooksImporter.read(folder: folder)
            return books.isEmpty ? StoreRead(trouble: "Apple Books gave no books. Open Books once and try again.") : StoreRead(books: books)
        } catch {
            return StoreRead(trouble: "Apple Books' list could not be read on this Mac.")
        }
    }

    static func readKindle() -> StoreRead {
        let folder = home.appendingPathComponent("Library/Containers/com.amazon.Kindle/Data/Library/Application Support/Kindle", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return StoreRead(trouble: "The Kindle app is not on this Mac.")
        }
        let books = (try? KindleImporter.read(folder: folder)) ?? []
        return StoreRead(books: books)
    }

    static func readKobo() -> StoreRead {
        let file = home.appendingPathComponent("Library/Application Support/Kobo/Kobo Desktop Edition/Kobo.sqlite")
        guard FileManager.default.fileExists(atPath: file.path) else {
            return StoreRead(trouble: "Kobo's Mac app is not set up on this Mac.")
        }
        do {
            let books = try KoboImporter.read(database: file)
            return books.isEmpty
                ? StoreRead(trouble: "Kobo's Mac app has no books yet. Sign in there and let it load your books.")
                : StoreRead(books: books)
        } catch {
            return StoreRead(trouble: "Kobo's list could not be read on this Mac.")
        }
    }
    #endif
}
