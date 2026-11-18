import AMSIcons
import ReadingCore
import SwiftUI

/// The third part of "Your reading": every author on the shelf, with what they have written there.
struct AuthorsPart: View {
    enum Order: String, CaseIterable { case most = "Most books", alphabet = "A to Z" }

    @EnvironmentObject private var model: ReadingModel
    @State private var query = ""
    @State private var order = Order.most
    private let colour = "purple"

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    private var lines: [AuthorLine] {
        var all = model.data.authors()
        let q = Self.fold(query.trimmingCharacters(in: .whitespaces))
        if !q.isEmpty { all = all.filter { Self.fold($0.name).contains(q) } }
        if order == .alphabet {
            all.sort { (BookMatch.authorKey($0.name), $0.name) < (BookMatch.authorKey($1.name), $1.name) }
        }
        return all
    }

    static func summary(_ line: AuthorLine) -> String {
        var parts = [line.owned == 1 ? "1 book" : "\(line.owned) books"]
        if line.finished > 0 { parts.append("\(line.finished) read") }
        if line.reading > 0 { parts.append("\(line.reading) reading") }
        if line.unread > 0 { parts.append("\(line.unread) not read") }
        if line.wishes > 0 { parts.append(line.wishes == 1 ? "1 wish" : "\(line.wishes) wishes") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let shown = lines
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    AppMarkView(.search, size: 14, colour: Theme.text(colour))
                    TextField("Search authors", text: $query)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("authors-search")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.text(colour).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                Menu {
                    Picker("Order", selection: $order) {
                        ForEach(Order.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(order.rawValue).font(.subheadline.weight(.semibold))
                        ControlMarkView(.chevron, size: 10, colour: Theme.text(colour))
                            .rotationEffect(.degrees(90))
                    }
                    .foregroundStyle(Theme.text(colour))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityIdentifier("authors-order")
            }
            Text(shown.count == 1 ? "1 author" : "\(shown.count) authors")
                .font(.headline)
                .foregroundStyle(Theme.text(colour))
                .accessibilityIdentifier("authors-count")
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(shown) { line in
                    NavigationLink(value: Route.author(line.name)) {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(line.name).font(.body).lineLimit(1)
                                Text(Self.summary(line)).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                            ControlMarkView(.chevron, size: 10, colour: .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("authors-row-\(line.name)")
                }
            }
            .accessibilityIdentifier("authors-list")
        }
    }
}
