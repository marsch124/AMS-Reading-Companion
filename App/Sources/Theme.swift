import AMSIcons
import ReadingCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The colours. Each shelf has its own colour for its heading and marks, one shade for day and one for night.
enum Theme {
    private static let shades: [String: (day: (Double, Double, Double), night: (Double, Double, Double))] = [
        "purple": ((0.48, 0.31, 0.54), (0.80, 0.66, 0.88)),
        "red": ((0.79, 0.29, 0.20), (1.00, 0.60, 0.50)),
        "green": ((0.07, 0.52, 0.35), (0.38, 0.84, 0.62)),
        "teal": ((0.02, 0.50, 0.53), (0.36, 0.82, 0.84)),
        "amber": ((0.70, 0.45, 0.02), (0.96, 0.75, 0.30)),
        "blue": ((0.14, 0.40, 0.84), (0.52, 0.72, 1.00)),
        "grey": ((0.40, 0.43, 0.48), (0.66, 0.69, 0.74)),
        "pink": ((0.74, 0.22, 0.47), (0.98, 0.58, 0.76)),
        "brown": ((0.55, 0.37, 0.20), (0.85, 0.68, 0.48)),
        "indigo": ((0.30, 0.32, 0.78), (0.66, 0.68, 1.00)),
        // Read + listen.
        "olive": ((0.38, 0.48, 0.08), (0.74, 0.84, 0.42)),
        // The reading notes.
        "orange": ((0.78, 0.38, 0.04), (1.00, 0.66, 0.34)),
        // The big filter and the shelves kept from it.
        "sea": ((0.04, 0.44, 0.64), (0.40, 0.78, 0.96)),
    ]

    /// For words: headings and links.
    static func text(_ name: String) -> Color {
        let s = shades[name] ?? shades["grey"]!
        return dynamic(day: s.day, night: s.night)
    }

    /// For a full-colour button or tile with white on top: the same strong shade day and night.
    static func fill(_ name: String) -> Color {
        let s = (shades[name] ?? shades["grey"]!).day
        return Color(red: s.0, green: s.1, blue: s.2)
    }

    /// Each store's dot.
    static func store(_ store: BookStore) -> Color {
        switch store {
        case .kobo: return dynamic(day: (0.85, 0.35, 0.19), night: (0.96, 0.52, 0.36))
        case .kindle: return dynamic(day: (0.16, 0.47, 0.87), night: (0.45, 0.70, 1.00))
        case .apple: return dynamic(day: (0.47, 0.47, 0.50), night: (0.66, 0.66, 0.70))
        case .own: return text("teal")
        }
    }

    static func dynamic(day: (Double, Double, Double), night: (Double, Double, Double)) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { look in
            let c = look.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? night : day
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? night : day
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }

    /// The plate behind a note.
    static var plate: Color {
        dynamic(day: (0.955, 0.96, 0.97), night: (0.17, 0.175, 0.19))
    }

    /// A calm tile colour for a book without a cover picture, the same for the same title every time.
    static func tile(for title: String) -> Color {
        let tiles: [(Double, Double, Double)] = [
            (0.48, 0.31, 0.54), (0.20, 0.44, 0.62), (0.13, 0.50, 0.42), (0.66, 0.36, 0.24),
            (0.62, 0.47, 0.14), (0.36, 0.38, 0.62), (0.56, 0.27, 0.38), (0.30, 0.46, 0.30),
        ]
        let sum = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9973 }
        let c = tiles[sum % tiles.count]
        return Color(red: c.0, green: c.1, blue: c.2)
    }
}

/// The full-colour main button. Never grey: a button that cannot be pressed yet is the same colour, only paler.
struct FilledButton: ButtonStyle {
    let colour: String
    @Environment(\.isEnabled) private var enabled

    init(colour: String) { self.colour = colour }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.fill(colour), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .contentShape(Rectangle())
    }
}

/// A book's cover: its picture, or a coloured tile with the title on it. Always 2 wide to 3 tall.
struct CoverView: View {
    let book: Book
    let width: CGFloat
    @EnvironmentObject private var covers: Covers

    init(book: Book, width: CGFloat) {
        self.book = book
        self.width = width
    }

    var body: some View {
        let address = covers.address(for: book)
        ZStack {
            tile
            if let address {
                AsyncImage(url: address) { phase in
                    if let picture = phase.image {
                        picture.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: max(2, width * 0.05), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: max(2, width * 0.05), style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .task(id: book.id) { await covers.lookUp(book) }
        .accessibilityHidden(true)
    }

    private var tile: some View {
        ZStack(alignment: .topLeading) {
            Theme.tile(for: book.title)
            if width >= 56 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: max(9, width * 0.13), weight: .semibold))
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                    Text(book.author)
                        .font(.system(size: max(8, width * 0.1)))
                        .lineLimit(2)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(width * 0.08)
            }
        }
    }
}

/// The small marks under a cover: one dot per store, an open lock for lock-free, headphones for an audiobook.
struct StoreMarks: View {
    let book: Book

    init(book: Book) { self.book = book }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(book.stores, id: \.self) { store in
                Circle().fill(Theme.store(store)).frame(width: 8, height: 8)
                    .accessibilityLabel(store.name)
            }
            if book.isLockFree {
                AppMarkView(.lockOpen, size: 13, colour: Theme.text("teal"))
                    .accessibilityLabel("Lock-free")
            }
            if book.isAudio {
                IconMark(.hand("headphones"), size: 13, colour: Theme.text("amber"))
                    .accessibilityLabel("Audiobook")
            }
            if book.wish {
                AppMarkView(.bookmark, size: 12, colour: Theme.text("blue"))
                    .accessibilityLabel("Wish")
            }
        }
        .frame(height: 13)
    }
}

/// Finds cover pictures. Kindle and Kobo covers have a known address; for an Apple Books book the address is
/// asked from Apple's public catalogue once, by the book's store number, and then remembered on this device.
@MainActor
final class Covers: ObservableObject {
    @Published private var found: [String: String]
    private var asked = Set<String>()
    private let key = "coverAddresses"
    private let triedKey = "coverTriedByTitle"
    /// Made-up books (`-sampleData`): nothing is ever asked. Read from the launch arguments at once, so no cover
    /// can be asked before a screen had the time to say so.
    var off = ProcessInfo.processInfo.arguments.contains("-sampleData")
    /// Where a cover found by title is kept: on the book itself, so every device gets it.
    var keep: ((_ bookID: String, _ address: String) -> Void)? {
        didSet {
            guard let keep else { return }
            for (id, address) in waiting { keep(id, address) }
            waiting = []
        }
    }
    /// Covers found before `keep` was set.
    private var waiting: [(String, String)] = []
    /// By-title questions go one after the other with a pause, so 25 new books do not ask 25 times at once.
    private var line: Task<Void, Never>?

    init() {
        found = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    func address(for book: Book) -> URL? {
        guard !off else { return nil }
        if let cover = book.coverURL, cover.hasPrefix("http"), let url = URL(string: cover) { return url }
        if let id = appleNumber(of: book), let cover = found[id], !cover.isEmpty { return URL(string: cover) }
        return nil
    }

    private func appleNumber(of book: Book) -> String? {
        book.copies.first { $0.store == .apple && !$0.storeID.isEmpty && $0.storeID.allSatisfy(\.isNumber) }?.storeID
    }

    func lookUp(_ book: Book) async {
        guard !off, book.coverURL == nil else { return }
        guard let id = appleNumber(of: book) else {
            await lookUpByTitle(book)
            return
        }
        guard found[id] == nil, !asked.contains(id) else { return }
        asked.insert(id)
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&country=se"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return }
        let small = results.first?["artworkUrl100"] as? String ?? ""
        found[id] = small.replacingOccurrences(of: "100x100", with: "400x400")
        UserDefaults.standard.set(found, forKey: key)
    }

    /// A book that came without a picture and without an Apple number (a Kindle book from a list, a book added by
    /// hand, a wish): its cover is asked once from a public book catalogue, by title and author.
    private func lookUpByTitle(_ book: Book) async {
        guard !book.title.isEmpty, !asked.contains(book.id) else { return }
        asked.insert(book.id)
        guard !(UserDefaults.standard.stringArray(forKey: triedKey) ?? []).contains(book.id) else { return }
        let id = book.id, title = book.title, author = book.author
        let before = line
        line = Task { [weak self] in
            await before?.value
            let answer = await CoverLookup.ask(title: title, author: author)
            guard let self else { return }
            if let cover = answer.cover {
                if let keep = self.keep { keep(id, cover) } else { self.waiting.append((id, cover)) }
            }
            // Only a real answer is remembered. A catalogue that could not be reached is asked again next time.
            if answer.answered {
                var tried = Set(UserDefaults.standard.stringArray(forKey: self.triedKey) ?? [])
                tried.insert(id)
                UserDefaults.standard.set(Array(tried), forKey: self.triedKey)
            }
            try? await Task.sleep(nanoseconds: 3_200_000_000)
        }
    }
}

/// The owner's stars for a book: five hand-drawn stars, the given ones filled. With `tap` they can be set.
struct StarsView: View {
    let rating: Int
    var size: CGFloat = 18
    var colour: String = "amber"
    var tap: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(1...5, id: \.self) { n in
                let star = GridShape(d: AppMark.star.path)
                ZStack {
                    if n <= rating { star.fill(Theme.text(colour)) }
                    star.stroke(Theme.text(colour), style: StrokeStyle(lineWidth: size / 24 * 1.9, lineCap: .round, lineJoin: .round))
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .onTapGesture { tap?(n == rating ? n - 1 : n) }
                .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
                .accessibilityIdentifier("star-\(n)")
                .accessibilityAddTraits(tap == nil ? [] : .isButton)
            }
        }
    }
}
