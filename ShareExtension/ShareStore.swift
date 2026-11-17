import Foundation
import ReadingCore

/// The files the app and the Share extension hand to each other, in the App Group. No UIKit here:
/// this same file is compiled into the app and into the extension.
enum ShareFiles {
    static let group = "group.com.schabbauer.AMSReadingCompanion"
    static let indexName = "shelf-index.json"
    static let wishesName = "pending-wishes.json"

    private struct Wish: Codable { var title: String; var author: String; var added: Double }

    private static func url(_ name: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent(name)
    }

    /// The app writes the shelf index; the extension reads it.
    static func writeIndex(_ entries: [ShelfEntry]) {
        guard let u = url(indexName), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: u, options: .atomic)
    }

    /// nil when the app has not written an index on this device yet.
    static func readIndex() -> [ShelfEntry]? {
        guard let u = url(indexName), let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode([ShelfEntry].self, from: data)
    }

    static func addWish(title: String, author: String) {
        guard let u = url(wishesName) else { return }
        var all = (try? Data(contentsOf: u)).flatMap { try? JSONDecoder().decode([Wish].self, from: $0) } ?? []
        all.append(Wish(title: title, author: author, added: Date().timeIntervalSince1970))
        if let data = try? JSONEncoder().encode(all) { try? data.write(to: u, options: .atomic) }
    }

    /// The app collects the wishes: reads them and empties the file.
    static func takeWishes() -> [(title: String, author: String)] {
        guard let u = url(wishesName), let data = try? Data(contentsOf: u),
              let all = try? JSONDecoder().decode([Wish].self, from: data) else { return [] }
        try? Data("[]".utf8).write(to: u, options: .atomic)
        return all.map { ($0.title, $0.author) }
    }
}
