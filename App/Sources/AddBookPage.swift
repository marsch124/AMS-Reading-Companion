import AMSIcons
import ReadingCore
import SwiftUI

/// Add a book by hand: to the wish list or to a store.
struct AddBookPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    var startTitle: String = ""
    @State private var title = ""
    @State private var author = ""
    @State private var place = "wish"

    private let colour = "blue"
    /// Save was pressed without a title: say so beside the field, instead of a button that cannot be pressed.
    @State private var titleMissing = false
    private let places: [(String, String)] = [("wish", "Wish list"), ("kindle", "Kindle"), ("kobo", "Kobo"),
                                              ("apple", "Apple Books"), ("own", "Own file")]

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var store: BookStore? {
        switch place {
        case "kindle": return .kindle
        case "kobo": return .kobo
        case "apple": return .apple
        case "own": return .own
        default: return nil
        }
    }

    private var owned: Book? {
        guard trimmedTitle.count >= 3 else { return nil }
        return model.data.ownedMatch(title: trimmedTitle, author: author)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("add-title")
                        .onChange(of: title) { _, _ in titleMissing = false }
                    if titleMissing {
                        Text("Type a title first.")
                            .font(.footnote)
                            .foregroundStyle(Theme.text("red"))
                            .accessibilityIdentifier("add-title-missing")
                    }
                    TextField("Author", text: $author)
                        .accessibilityIdentifier("add-author")
                    Picker("Where", selection: $place) {
                        ForEach(places, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .accessibilityIdentifier("add-where")
                }
                if let book = owned {
                    Section {
                        let names = book.stores.map(\.name).joined(separator: " and ")
                        Text("You already own “\(book.title)” — in \(names).")
                            .font(.callout)
                            .foregroundStyle(Theme.text("red"))
                            .accessibilityIdentifier("add-owned")
                    }
                    .listRowBackground(Theme.plate)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Add a book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) { ControlMarkView(.close, size: 18); Text("Cancel") }
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("add-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        HStack(spacing: 4) { ControlMarkView(.check, size: 16, colour: .white); Text("Save") }
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("add-save")
                }
            }
            .onAppear { if title.isEmpty { title = startTitle } }
        }
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    private func save() {
        guard !trimmedTitle.isEmpty else {
            titleMissing = true
            return
        }
        model.add(title: trimmedTitle, author: author.trimmingCharacters(in: .whitespacesAndNewlines), store: store)
        dismiss()
    }
}
