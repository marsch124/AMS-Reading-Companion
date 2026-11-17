import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ReadingCore

final class ShareViewController: UIViewController {
    private var shown = false

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            let page = await Self.readPage(extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            showSheet(page: page)
        }
        // Fallback: never stay blank. After 3 seconds show the not-found state with empty fields.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showSheet(page: "")
        }
    }

    private func showSheet(page: String) {
        guard !shown else { return }
        shown = true
        let model = ShareModel(pageTitle: page, index: ShareFiles.readIndex()) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: ShareSheet(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    /// The page title: the item's title, else shared text, else the last words of the URL.
    private static func readPage(_ items: [NSExtensionItem]) async -> String {
        var title = ""
        var text = ""
        var url: URL?
        for item in items {
            if title.isEmpty, let t = item.attributedTitle?.string ?? item.attributedContentText?.string,
               !t.trimmingCharacters(in: .whitespaces).isEmpty { title = t }
            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let o = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                    if let u = o as? URL { url = u } else if let s = o as? String { url = URL(string: s) }
                }
                if text.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let s = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { text = s }
            }
        }
        if !title.isEmpty { return title }
        if let u = url ?? URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), u.host != nil {
            let junk: Set<String> = ["book", "books", "dp", "gp", "product", "ebook", "en", "se", "us"]
            let words = u.pathComponents.filter { $0 != "/" }
                .filter { part in !junk.contains(part.lowercased()) && !part.contains(where: \.isNumber) }
                .flatMap { $0.split(whereSeparator: { "-_+. ".contains($0) }) }
                .map(String.init)
            let joined = words.joined(separator: " ")
            return joined.isEmpty ? (u.host ?? "") : joined
        }
        return text
    }
}

@MainActor
final class ShareModel: ObservableObject {
    let pageTitle: String
    let index: [ShelfEntry]?
    let close: () -> Void
    @Published var title: String
    @Published var author: String
    @Published var added = false

    init(pageTitle: String, index: [ShelfEntry]?, close: @escaping () -> Void) {
        self.pageTitle = pageTitle; self.index = index; self.close = close
        title = ShareMatch.likelyTitle(pageTitle); author = ShareMatch.likelyAuthor(pageTitle)
    }

    var matches: [ShelfEntry] { index.map { ShareMatch.find(pageTitle: pageTitle, in: $0) } ?? [] }
    /// On the shelf in a store (or a plain entry).
    var owned: [ShelfEntry] { matches.filter { !($0.wish && $0.stores.isEmpty) } }
    /// Only on the wish list, in no store.
    var wished: [ShelfEntry] { matches.filter { $0.wish && $0.stores.isEmpty } }

    func addWish() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        ShareFiles.addWish(title: t, author: author.trimmingCharacters(in: .whitespacesAndNewlines))
        close()
    }
}

extension Color {
    fileprivate static func adaptive(day: (Double, Double, Double), night: (Double, Double, Double)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? night : day
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
    static let sharePurple = adaptive(day: (0.48, 0.31, 0.54), night: (0.80, 0.66, 0.88))
    static let shareGreen = adaptive(day: (0.07, 0.52, 0.35), night: (0.38, 0.84, 0.62))
    static let shareRed = adaptive(day: (0.79, 0.29, 0.20), night: (1.00, 0.60, 0.50))
    /// Full-colour button background: always the day value, with white text.
    static let shareButton = Color(red: 0.48, green: 0.31, blue: 0.54)
}

struct ShareSheet: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AMS Reading").font(.headline).foregroundStyle(Color.sharePurple)
            if model.index == nil {
                Text("Open AMS Reading once on this device, then try again.")
                    .font(.body).accessibilityIdentifier("share-no-index")
                Spacer(minLength: 0)
                doneButton
            } else if !model.matches.isEmpty {
                if !model.owned.isEmpty {
                    Text("You own this").font(.headline).foregroundStyle(Color.shareGreen).accessibilityIdentifier("share-owned")
                    bookList(model.owned)
                }
                if !model.wished.isEmpty {
                    Text("Already on your wish list").font(.headline).foregroundStyle(Color.sharePurple).accessibilityIdentifier("share-wished")
                    bookList(model.wished)
                }
                Spacer(minLength: 0)
                doneButton
            } else {
                Text("Not on your shelf").font(.headline).foregroundStyle(Color.shareRed).accessibilityIdentifier("share-none")
                TextField("Title", text: $model.title).textFieldStyle(.roundedBorder).accessibilityIdentifier("share-title")
                TextField("Author", text: $model.author).textFieldStyle(.roundedBorder).accessibilityIdentifier("share-author")
                Spacer(minLength: 0)
                Button(action: model.addWish) {
                    Text("Save to wish list").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.shareButton, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                }
                .buttonStyle(.plain).accessibilityIdentifier("share-add-wish")
                Button(action: model.close) {
                    Text("Cancel").font(.body).frame(maxWidth: .infinity).padding(.vertical, 6)
                        .foregroundStyle(Color.sharePurple)
                }
                .buttonStyle(.plain).accessibilityIdentifier("share-cancel")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var doneButton: some View {
        Button(action: model.close) {
            Text("Done").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color.shareButton, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
        }
        .buttonStyle(.plain).accessibilityIdentifier("share-done")
    }

    private func bookList(_ books: [ShelfEntry]) -> some View {
        ForEach(books, id: \.self) { book in
            VStack(alignment: .leading, spacing: 2) {
                Text(book.author.isEmpty ? book.title : "\(book.title) — \(book.author)").font(.body)
                Text(detail(book)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func detail(_ b: ShelfEntry) -> String {
        var parts: [String] = []
        if !b.stores.isEmpty { parts.append("in " + list(b.stores)) }
        if b.wish { parts.append("On your wish list") }
        return parts.joined(separator: " · ")
    }

    private func list(_ names: [String]) -> String {
        names.count < 2 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names.last!
    }
}
