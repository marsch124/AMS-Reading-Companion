import AMSIcons
import ReadingCore
import SwiftUI

// The author's page and the series' page. Both are pushed onto the stack that is already there.

/// Every book of one author: on the shelf, and on the wish list.
struct AuthorPage: View {
    @EnvironmentObject private var model: ReadingModel
    let author: String

    private let colour = "indigo"

    var body: some View {
        let books = model.data.books(by: author)
        let owned = books.filter { !$0.wish }
        let wished = books.filter { $0.wish }
        let finished = books.filter { model.data.state(of: $0) == .finished }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if books.isEmpty {
                    Text("No book by this author is on your shelf.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("author-empty")
                } else {
                    Text(countLine(total: books.count, owned: owned.count, wished: wished.count, finished: finished))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("author-count")
                    group("On your shelf", owned)
                    group("Wish list", wished)
                }
            }
            .padding(12)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(books.first?.author ?? author)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("author-page")
    }

    private func countLine(total: Int, owned: Int, wished: Int, finished: Int) -> String {
        var parts = [total == 1 ? "1 book" : "\(total) books"]
        if owned > 0 { parts.append("\(owned) on your shelf") }
        if wished > 0 { parts.append("\(wished) wished") }
        if finished > 0 { parts.append("\(finished) finished") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func group(_ title: String, _ books: [Book]) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text(colour))
                    .padding(.top, 4)
                ForEach(books) { book in row(book) }
            }
        }
    }

    private func row(_ book: Book) -> some View {
        BookLink(id: book.id) {
            HStack(spacing: 10) {
                CoverView(book: book, width: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title).font(.body).lineLimit(2).multilineTextAlignment(.leading)
                    if let series = book.series, !series.isEmpty {
                        Text(seriesLine(series, book.seriesNumber))
                            .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.data.state(of: book).name).font(.footnote).foregroundStyle(.secondary)
                    StoreMarks(book: book)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("author-book-\(book.id)")
    }

    private func seriesLine(_ series: String, _ number: Double?) -> String {
        guard let number else { return series }
        let text = number == number.rounded() ? String(Int(number)) : String(number)
        return "\(series) · \(text)"
    }
}

/// Every part of one series, in order: owned, wished or missing.
struct SeriesPage: View {
    @EnvironmentObject private var model: ReadingModel
    let series: String
    @State private var settingLength = false

    private let colour = "green"

    var body: some View {
        let head = model.data.seriesHead(series)
        let parts = model.data.seriesParts(series)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !head.author.isEmpty {
                    Text(head.author).font(.body).foregroundStyle(.secondary)
                }
                Text(countLine(parts))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("series-count")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parts) { part in
                        partRow(part, head: head.name)
                            .accessibilityIdentifier("series-part-\(part.number.map(String.init) ?? part.id)")
                    }
                }
                .padding(.top, 4)
                if !model.readOnly {
                    Button { settingLength = true } label: { smallFilled("Set length") }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .accessibilityIdentifier("series-set-length")
                }
            }
            .padding(12)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(head.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("series-page")
        .sheet(isPresented: $settingLength) { SeriesLengthPage(name: head.name) }
    }

    private func countLine(_ parts: [SeriesPart]) -> String {
        let owned = parts.filter { $0.kind == .owned }
        let finished = owned.filter { $0.book.map { model.data.state(of: $0) == .finished } ?? false }.count
        let wished = parts.filter { $0.kind == .wish }.count
        let missing = parts.filter { $0.kind == .missing }.count
        var out: [String] = []
        if missing > 0 || wished > 0 {
            out.append("\(owned.count) of \(parts.count) owned")
        } else {
            out.append("\(owned.count) owned")
        }
        if finished > 0 { out.append("\(finished) finished") }
        if wished > 0 { out.append("\(wished) wished") }
        if missing > 0 { out.append("\(missing) missing") }
        return out.joined(separator: " · ")
    }

    @ViewBuilder
    private func partRow(_ part: SeriesPart, head: String) -> some View {
        switch part.kind {
        case .owned, .wish:
            if let book = part.book {
                BookLink(id: book.id) {
                    HStack(spacing: 10) {
                        badge(part)
                        Text(part.title ?? book.title).font(.body).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 6)
                        if part.kind == .owned {
                            let state = model.data.state(of: book)
                            Text(state.name).font(.footnote).foregroundStyle(.secondary)
                            if state == .finished {
                                ControlMarkView(.check, size: 14, colour: Theme.text(colour))
                                    .accessibilityHidden(true)
                            }
                        } else {
                            Text("On your wish list").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        case .missing:
            HStack(spacing: 10) {
                badge(part)
                if let title = part.title, !title.isEmpty {
                    Text(title).font(.body).lineLimit(2)
                } else {
                    Text("Title not known").font(.body).foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                if !model.readOnly, let n = part.number {
                    Button { model.wishSeriesPart(series: head, number: n, title: part.title) } label: {
                        smallFilled("Wish")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("series-wish-\(n)")
                }
            }
        }
    }

    private func badge(_ part: SeriesPart) -> some View {
        let missing = part.kind == .missing
        return Text(part.number.map(String.init) ?? "–")
            .font(.footnote.weight(.bold))
            .foregroundStyle(missing ? Color.secondary : Theme.text(colour))
            .frame(width: 26, height: 26)
            .background(Circle().strokeBorder(missing ? Color.secondary.opacity(0.5) : Theme.text(colour), lineWidth: 1.5))
    }

    private func smallFilled(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.fill(colour), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }
}
