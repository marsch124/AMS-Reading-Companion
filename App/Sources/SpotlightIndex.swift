import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import ReadingCore

/// Puts the owner's shelf into the device's own search. Everything stays on this device; nothing is sent anywhere.
enum SpotlightIndex {
    private static let domain = "books"
    private static let fingerprintKey = "spotlightIndexFingerprint"

    /// Puts the shelf into the device's search. Does nothing when the list is the same as last time.
    static func update(_ books: [Book]) {
        let live = books.filter { !$0.removed }
        let print = fingerprint(live)
        let defaults = UserDefaults.standard
        if defaults.string(forKey: fingerprintKey) == print { return }

        let items = live.map(item(for:))
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { error in
            if error != nil { return }
            if items.isEmpty {
                defaults.set(print, forKey: fingerprintKey)
                return
            }
            index.indexSearchableItems(items) { error in
                if error == nil { defaults.set(print, forKey: fingerprintKey) }
            }
        }
    }

    /// The book a tap in the device's search asks for, or nil.
    static func bookID(from activity: NSUserActivity) -> String? {
        guard activity.activityType == CSSearchableItemActionType else { return nil }
        return activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
    }

    /// Takes every book out of the device's search.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: fingerprintKey)
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
    }

    private static func item(for book: Book) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = book.title
        var line: String
        if book.wish && book.copies.isEmpty {
            line = "On your wish list"
        } else {
            line = "You own this"
            let names = book.stores.map(\.name).joined(separator: ", ")
            if !names.isEmpty { line += " · " + names }
            if book.onlyAudio { line += " · audiobook" }
        }
        if !book.author.isEmpty {
            line += " · " + book.author
            attrs.authorNames = [book.author]
        }
        attrs.contentDescription = line
        var words = [String]()
        if !book.author.isEmpty { words.append(book.author) }
        if let s = book.series, !s.isEmpty { words.append(s) }
        words.append("book")
        attrs.keywords = words
        return CSSearchableItem(uniqueIdentifier: book.id, domainIdentifier: domain, attributeSet: attrs)
    }

    /// A stable fingerprint (not Swift's hashValue, which changes every launch): FNV-1a over the fields that show in search.
    private static func fingerprint(_ books: [Book]) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        func feed(_ s: String) {
            for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        }
        for b in books {
            feed("\(b.id)|\(b.title)|\(b.author)|\(b.series ?? "")|\(b.stores.map(\.name).joined(separator: ","))|\(b.onlyAudio)|\(b.wish)\n")
        }
        return "\(books.count):\(h)"
    }
}
