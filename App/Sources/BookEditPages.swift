import ReadingCore
import SwiftUI

/// The owner's correction of a book's title, author and series.
struct CorrectBookPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var title = ""
    @State private var author = ""
    @State private var series = ""
    @State private var number = ""
    @State private var loaded = false

    private let colour = "purple"

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var parsedNumber: Double? {
        let text = number.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return text.isEmpty ? nil : Double(text)
    }

    private func shown(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1_000_000 ? String(Int(value)) : String(value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Title", text: $title, id: "correct-title")
                    field("Author", text: $author, id: "correct-author")
                    field("Series", text: $series, id: "correct-series")
                    field("Number in the series", text: $number, id: "correct-number", decimal: true)
                } footer: {
                    Text("After you save, the store's list no longer changes these for this book.")
                }
                if model.data.book(bookID)?.detailsByHand == true {
                    Section {
                        Button("Use the store's words again") {
                            model.uncorrect(bookID)
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.text(colour))
                        .accessibilityIdentifier("correct-undo")
                    } footer: {
                        Text("The title, author and series from before your correction come back at once.")
                    }
                }
            }
            .navigationTitle("Correct this book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("correct-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.correct(bookID, title: title, author: author, series: series, number: parsedNumber)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .accessibilityIdentifier("correct-save")
                }
            }
        }
        .accessibilityIdentifier("correct-page")
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let book = model.data.book(bookID) {
                title = book.title
                author = book.author
                series = book.series ?? ""
                number = book.seriesNumber.map(shown) ?? ""
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 400)
        #endif
    }

    private func field(_ label: String, text: Binding<String>, id: String, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.text(colour))
            TextField(label, text: text)
                #if os(iOS)
                .keyboardType(decimal ? .decimalPad : .default)
                #endif
                .accessibilityIdentifier(id)
        }
    }
}

/// The tags of one book, chosen from the tags in use or newly typed.
struct TagsPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var onTags: [String] = []
    @State private var newTag = ""
    @State private var loaded = false

    private let colour = "teal"

    private func isOn(_ tag: String) -> Bool {
        let key = LibraryData.tagKey(tag)
        return onTags.contains { LibraryData.tagKey($0) == key }
    }

    private func toggle(_ tag: String) {
        let key = LibraryData.tagKey(tag)
        if isOn(tag) {
            onTags.removeAll { LibraryData.tagKey($0) == key }
        } else {
            onTags = LibraryData.cleanTags(onTags + [tag])
        }
    }

    private func add() {
        let typed = newTag
        newTag = ""
        onTags = LibraryData.cleanTags(onTags + [typed])
    }

    private var storeTags: [String] {
        model.data.book(bookID)?.storeTags ?? []
    }

    private var others: [(tag: String, count: Int)] {
        let store = Set(storeTags.map(LibraryData.tagKey))
        return model.data.allTags().filter { !isOn($0.tag) && !store.contains(LibraryData.tagKey($0.tag)) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if onTags.isEmpty && others.isEmpty {
                        Text("No tags yet. Type your first one, for example “travel” or “to give away”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ChipFlow {
                            ForEach(onTags, id: \.self) { tag in
                                Chip(title: tag, colour: colour, on: true) { toggle(tag) }
                                    .accessibilityIdentifier("tag-\(LibraryData.tagKey(tag))")
                            }
                            ForEach(others, id: \.tag) { item in
                                Chip(title: item.tag, count: item.count, colour: colour, on: false) { toggle(item.tag) }
                                    .accessibilityIdentifier("tag-\(LibraryData.tagKey(item.tag))")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                if !storeTags.isEmpty {
                    Section {
                        ChipFlow {
                            ForEach(storeTags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Circle().fill(Theme.text(colour)).frame(width: 6, height: 6)
                                    Text(tag)
                                    Text("from the store").font(.caption2).foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                .foregroundStyle(Theme.text(colour))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .overlay(Capsule().stroke(Theme.text(colour).opacity(0.45), lineWidth: 1))
                                .accessibilityIdentifier("tags-store-\(LibraryData.tagKey(tag))")
                            }
                        }
                        .padding(.vertical, 2)
                    } footer: {
                        Text("These come from your collections in Apple Books or Kobo. Change them there.")
                    }
                }
                Section {
                    HStack {
                        TextField("New tag", text: $newTag)
                            .onSubmit(add)
                            .accessibilityIdentifier("tags-field")
                        Button("Add", action: add)
                            .buttonStyle(FilledButton(colour: colour))
                            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("tags-add")
                    }
                } header: {
                    Text("New tag").foregroundStyle(Theme.text(colour))
                }
            }
            .navigationTitle("Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("tags-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // A tag still standing in the field counts too.
                        add()
                        model.setTags(onTags, of: bookID)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("tags-save")
                }
            }
        }
        .accessibilityIdentifier("tags-page")
        .onAppear {
            guard !loaded else { return }
            loaded = true
            onTags = model.data.book(bookID)?.tags ?? []
        }
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }
}
