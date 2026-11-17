import SwiftUI
import UIKit
import WidgetKit

// MARK: - Entry

struct ReadingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let covers: [String: UIImage]
}

// MARK: - Provider

struct ReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: Date(), snapshot: WidgetSnapshot(
            reading: [WidgetBook(id: "x", title: "A Book Title", author: "Author", coverURL: nil, tint: "A Book Title")],
            next: WidgetBook(id: "y", title: "Another Title", author: "Author", coverURL: nil, tint: "Another Title"),
            nextReason: "From an author you read"), covers: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(ReadingEntry(date: Date(), snapshot: WidgetFiles.read(), covers: [:]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        let snap = WidgetFiles.read()
        let refresh = Date().addingTimeInterval(6 * 3600)
        guard let snap else {
            completion(Timeline(entries: [ReadingEntry(date: Date(), snapshot: nil, covers: [:])], policy: .after(refresh)))
            return
        }
        var wanted: [WidgetBook] = Array(snap.reading.prefix(2))
        if let n = snap.next { wanted.append(n) }
        wanted = Array(wanted.prefix(3))
        Task {
            var covers: [String: UIImage] = [:]
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for b in wanted {
                    guard let s = b.coverURL, let url = URL(string: s) else { continue }
                    group.addTask { (b.id, await Self.fetch(url)) }
                }
                for await (id, img) in group { if let img { covers[id] = img } }
            }
            completion(Timeline(entries: [ReadingEntry(date: Date(), snapshot: snap, covers: covers)], policy: .after(refresh)))
        }
    }

    private static func fetch(_ url: URL) async -> UIImage? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return downsample(data, maxPixel: 300)
    }

    private static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary) else { return nil }
        let thumb: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumb as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Colours (copied from the app's Theme)

private enum Palette {
    static let purple = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.80, green: 0.66, blue: 0.88, alpha: 1) : UIColor(red: 0.48, green: 0.31, blue: 0.54, alpha: 1)
    })

    /// Same colour as Theme.tile(for:) in the app.
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

private func bookURL(_ id: String) -> URL {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/:")
    let enc = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
    return URL(string: "amsreading://book/\(enc)") ?? URL(string: "amsreading://")!
}

// MARK: - Views

private struct CoverView: View {
    let book: WidgetBook
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Palette.tile(for: book.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.caption.weight(.semibold)).lineLimit(4).minimumScaleFactor(0.8)
                    Text(book.author).font(.caption2).lineLimit(1).opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(6)
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

private func heading(_ s: String) -> some View {
    Text(s).font(.caption.weight(.semibold)).foregroundStyle(Palette.purple).lineLimit(1)
}

struct ReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadingEntry

    var body: some View {
        Group {
            if let s = entry.snapshot, !(s.reading.isEmpty && s.next == nil) {
                if family == .systemSmall { small(s) } else { medium(s) }
            } else {
                Text("Open AMS Reading once to fill this.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder private func small(_ s: WidgetSnapshot) -> some View {
        let book = s.reading.first ?? s.next
        VStack(alignment: .leading, spacing: 4) {
            heading(s.reading.isEmpty ? "What next?" : "Reading now")
            if let book {
                CoverView(book: book, image: entry.covers[book.id])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(book.map { bookURL($0.id) })
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                heading("Reading now")
                if s.reading.isEmpty {
                    Text("Nothing yet").font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(s.reading.prefix(2)), id: \.id) { b in
                            Link(destination: bookURL(b.id)) { CoverView(book: b, image: entry.covers[b.id]) }
                                .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 4) {
                heading("What next?")
                if let n = s.next {
                    Link(destination: bookURL(n.id)) {
                        HStack(alignment: .top, spacing: 8) {
                            CoverView(book: n, image: entry.covers[n.id])
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.title).font(.footnote.weight(.semibold)).lineLimit(2).foregroundStyle(.primary)
                                if let r = s.nextReason {
                                    Text(r).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Nothing yet").font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Widget

struct ReadingWidget: Widget {
    let kind = "ReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingProvider()) { entry in
            ReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading")
        .description("What you are reading now, and what could come next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ReadingWidgetBundle: WidgetBundle {
    var body: some Widget { ReadingWidget() }
}
