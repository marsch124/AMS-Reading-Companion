import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ReadingCore

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            let page = await Self.readPage(extensionContext?.inputItems as? [NSExtensionItem] ?? [])
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
            let words = u.pathComponents.filter { $0 != "/" }
                .flatMap { $0.split(whereSeparator: { "-_+. ".contains($0) }) }
                .map(String.init).filter { !$0.allSatisfy(\.isNumber) }
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

    func addWish() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        ShareFiles.addWish(title: t, author: author.trimmingCharacters(in: .whitespacesAndNewlines))
        close()
    }
}

struct ShareSheet: View {
    @ObservedObject var model: ShareModel
    private let purple = Color(red: 0.48, green: 0.31, blue: 0.54)
    private let green = Color(red: 0.20, green: 0.55, blue: 0.30)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AMS Reading").font(.headline).foregroundStyle(purple)
            if model.index == nil {
                Text("Open AMS Reading once on this device, then try again.")
                    .font(.body).accessibilityIdentifier("share-no-index")
            } else if !model.matches.isEmpty {
                Text("You own this").font(.headline).foregroundStyle(green).accessibilityIdentifier("share-owned")
                ForEach(model.matches, id: \.title) { book in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.author.isEmpty ? book.title : "\(book.title) — \(book.author)").font(.body)
                        Text(detail(book)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Not on your shelf").font(.headline).foregroundStyle(.orange).accessibilityIdentifier("share-none")
                TextField("Title", text: $model.title).textFieldStyle(.roundedBorder).accessibilityIdentifier("share-title")
                TextField("Author", text: $model.author).textFieldStyle(.roundedBorder).accessibilityIdentifier("share-author")
                Button(action: model.addWish) {
                    Text("Add to wish list").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(purple, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                }
                .buttonStyle(.plain).accessibilityIdentifier("share-add-wish")
            }
            Spacer(minLength: 0)
            Button(action: model.close) {
                Text("Done").font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(purple, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
            }
            .buttonStyle(.plain).accessibilityIdentifier("share-done")
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
