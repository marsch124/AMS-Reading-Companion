import AMSIcons
import ReadingCore
import SwiftUI

/// Search the shelf by title, author or series: "do I already own it?"
struct SearchView: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var adding = false
    @FocusState private var focused: Bool

    private let colour = "purple"

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [Book] { query.isEmpty ? [] : model.data.find(query) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                field
                if !query.isEmpty {
                    if results.isEmpty { none } else { list }
                } else {
                    Text("Type a title, an author or a series to see whether you already own it, and in which store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("search-hint")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("search-done")
                }
            }
            .onAppear { focused = true }
            .sheet(isPresented: $adding) { AddBookPage(startTitle: query) }
        }
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    private var field: some View {
        HStack(spacing: 8) {
            AppMarkView(.search, size: 18)
                .foregroundStyle(Theme.text(colour))
            TextField("Title, author or series", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("search-field")
            if !text.isEmpty {
                Button { text = "" } label: { ControlMarkView(.close, size: 18) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search-clear")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8))
    }

    private var none: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not on your shelf.")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("search-none")
            Button { adding = true } label: {
                Text("Add “\(query)”…").lineLimit(1)
            }
            .buttonStyle(FilledButton(colour: "blue"))
            .accessibilityIdentifier("search-add")
        }
    }

    private var countLine: String {
        let owned = results.filter { !$0.wish }.count
        if owned > 0 { return owned == 1 ? "You own 1 matching book." : "You own \(owned) matching books." }
        return results.count == 1 ? "1 matching book." : "\(results.count) matching books."
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(countLine)
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("search-count")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(results) { book in
                        NavigationLink {
                            BookPage(bookID: book.id)
                        } label: {
                            row(book)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("result-\(book.id)")
                    }
                }
            }
        }
    }

    private func row(_ book: Book) -> some View {
        HStack(spacing: 10) {
            CoverView(book: book, width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).font(.body.weight(.semibold)).lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    StoreMarks(book: book)
                    if book.wish {
                        Text("Wish").font(.footnote.weight(.semibold)).foregroundStyle(Theme.text("blue"))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
