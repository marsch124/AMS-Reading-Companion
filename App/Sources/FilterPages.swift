import AMSIcons
import ReadingCore
import SwiftUI

/// The big filter: every way to narrow the whole shelf down on one page. Tap what you want; inside one group a
/// book needs one of your choices, across groups it needs all of them. The main button counts as you tap.
/// With `kept` it changes a filter that was kept as a shelf (its name, its choices) or removes that shelf.
struct FilterPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    var start = BookFilter()
    var kept: SavedFilter?
    /// "Show 42 books" was pressed.
    var onShow: (BookFilter) -> Void = { _ in }
    /// The filter was kept as a shelf.
    var onKeep: (SavedFilter) -> Void = { _ in }

    @State private var filter = BookFilter()
    @State private var name = ""
    @State private var loaded = false
    @State private var naming = false
    @State private var askRemove = false

    private let colour = "sea"

    var body: some View {
        let found = model.data.books(matching: filter).count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if kept != nil {
                        TextField("Name of the shelf", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("filter-name")
                    }
                    groups
                    if kept != nil, !model.readOnly {
                        Button { askRemove = true } label: {
                            Text("Remove this shelf")
                                .foregroundStyle(Theme.text("red"))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .accessibilityIdentifier("filter-remove")
                        .confirmationDialog("Remove this shelf? Its books stay on your shelf.", isPresented: $askRemove,
                                            titleVisibility: .visible) {
                            Button("Remove", role: .destructive) {
                                if let kept { model.removeKeptFilter(kept.id) }
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) { bottom(found) }
            .navigationTitle(kept == nil ? "Filter" : "Change shelf")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("filter-cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    if !filter.isEmpty {
                        Button("Clear") { filter = BookFilter() }
                            .foregroundStyle(Theme.text(colour))
                            .accessibilityIdentifier("filter-clear")
                    }
                }
            }
        }
        .accessibilityIdentifier("filter-page")
        .onAppear {
            guard !loaded else { return }
            loaded = true
            filter = kept?.filter ?? start
            name = kept?.name ?? ""
        }
        .alert("Keep as a shelf", isPresented: $naming) {
            TextField("Name", text: $name)
                .accessibilityIdentifier("filter-keep-name")
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let made = model.keepFilter(filter, name: name) {
                    dismiss()
                    onKeep(made)
                }
            }
        } message: {
            Text("The shelf shows on the main screen with the books that fit, always up to date.")
        }
        #if os(macOS)
        .frame(width: 500, height: 640)
        #endif
    }

    // MARK: The groups of choices

    @ViewBuilder
    private var groups: some View {
        let numbers = model.data.numbers()
        let owned = model.data.owned
        group("Store") {
            ForEach([BookStore.kobo, .kindle, .apple, .own], id: \.self) { store in
                let count = owned.filter { $0.copies.contains { $0.store == store } }.count
                if count > 0 {
                    chip(store.name, count, filter.stores.contains(store), "store-\(store.rawValue)") { toggle(&filter.stores, store) }
                }
            }
        }
        group("Kind") {
            ForEach([BookKind.ebook, .audiobook, .pdf], id: \.self) { kind in
                let count = owned.filter { $0.copies.contains { $0.kind == kind } }.count
                if count > 0 {
                    chip(BookFilter.kindName(kind), count, filter.kinds.contains(kind), "kind-\(kind.rawValue)") { toggle(&filter.kinds, kind) }
                }
            }
        }
        group("Language") {
            ForEach(LibraryData.languages(in: owned), id: \.code) { language in
                chip(BookLanguage.name(language.code), language.count, filter.languages.contains(language.code),
                     "language-\(language.code)") { toggle(&filter.languages, language.code) }
            }
            let unknown = owned.filter { $0.language == nil }.count
            if unknown > 0 {
                chip("Not known", unknown, filter.languages.contains(""), "language-unknown") { toggle(&filter.languages, "") }
            }
        }
        group("Status") {
            ForEach(ShelfState.allCases, id: \.self) { state in
                chip(state.name, nil, filter.states.contains(state), "state-\(state.rawValue)") { toggle(&filter.states, state) }
            }
        }
        group("Your stars") {
            ForEach([3, 4, 5, 0], id: \.self) { stars in
                chip(stars == 0 ? "None yet" : (stars == 5 ? "5" : "\(stars) or more"), nil, filter.stars == stars, "stars-\(stars)") {
                    filter.stars = filter.stars == stars ? nil : stars
                }
            }
        }
        let bought = model.data.boughtYears()
        if !bought.isEmpty {
            group("Bought") {
                ForEach(bought.prefix(3), id: \.self) { year in
                    chip(String(year), nil, filter.boughtYears.contains(year), "bought-\(year)") { toggle(&filter.boughtYears, year) }
                }
                if bought.count > 3, let before = bought.prefix(3).last {
                    chip("Earlier", nil, filter.boughtBefore != nil, "bought-earlier") {
                        filter.boughtBefore = filter.boughtBefore == nil ? before : nil
                    }
                }
            }
        }
        let finished = model.data.finishedYears()
        if !finished.isEmpty {
            group("Finished") {
                ForEach(finished.prefix(5), id: \.self) { year in
                    chip(String(year), nil, filter.finishedYears.contains(year), "finished-\(year)") { toggle(&filter.finishedYears, year) }
                }
            }
        }
        let tags = model.data.allTags()
        if !tags.isEmpty {
            group("Tags") {
                ForEach(tags, id: \.tag) { tag in
                    let key = LibraryData.tagKey(tag.tag)
                    chip(tag.tag, tag.count, filter.tags.contains(key), "tag-\(key)") { toggle(&filter.tags, key) }
                }
            }
        }
        if numbers.lockFree > 0 {
            group("Lock") {
                chip("Lock-free", numbers.lockFree, filter.lockFree, "lockfree") { filter.lockFree.toggle() }
            }
        }
    }

    private func group<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text(colour))
            ChipFlow { chips() }
        }
    }

    private func chip(_ title: String, _ count: Int?, _ on: Bool, _ id: String, action: @escaping () -> Void) -> some View {
        Chip(title: title, count: count, colour: colour, on: on, action: action)
            .accessibilityIdentifier("filter-\(id)")
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: The buttons at the bottom

    private func bottom(_ found: Int) -> some View {
        VStack(spacing: 6) {
            if let kept {
                Button {
                    model.changeKeptFilter(kept.id, name: name, filter: filter)
                    dismiss()
                } label: {
                    Text(found == 1 ? "Save · 1 book" : "Save · \(found) books")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButton(colour: colour))
                .disabled(filter.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty || model.readOnly)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("filter-save")
            } else {
                Button {
                    dismiss()
                    onShow(filter)
                } label: {
                    Text(showWords(found))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButton(colour: colour))
                .disabled(found == 0)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("filter-show")
                // Only a filter with a choice can be kept: without one the words are left out, not shown pale.
                if !model.readOnly, !filter.isEmpty {
                    Button {
                        name = String(filter.words.prefix(40))
                        naming = true
                    } label: {
                        Text("Keep as a shelf")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text(colour))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter-keep")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func showWords(_ found: Int) -> String {
        if filter.isEmpty { return "Show all \(found) books" }
        switch found {
        case 0: return "No book fits"
        case 1: return "Show 1 book"
        default: return "Show \(found) books"
        }
    }
}

/// The books that fit a filter, as a grid of covers. "Change" goes back to the choices; "Keep" makes it a shelf.
struct FilterResultsPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.openRoute) private var openRoute
    @State var filter: BookFilter
    @State private var changing = false
    @State private var naming = false
    @State private var name = ""
    @State private var keptName: String?

    private let colour = "sea"

    var body: some View {
        let books = model.data.books(matching: filter)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(filter.isEmpty ? "Every book on your shelf" : filter.words)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text(colour))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("results-words")
                Text(books.isEmpty ? "No book fits." : (books.count == 1 ? "1 book" : "\(books.count) books"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("results-count")
                if let keptName {
                    Text("Kept as the shelf “\(keptName)”. It is on the main screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("results-kept")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 10, alignment: .top)], spacing: 12) {
                    ForEach(books) { book in
                        VStack(alignment: .leading, spacing: 3) {
                            BookTile(book: book, width: 92)
                            Text(book.title)
                                .font(.caption)
                                .lineLimit(2)
                                .frame(width: 92, alignment: .leading)
                        }
                        .accessibilityIdentifier("result-\(book.id)")
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Filter")
        .accessibilityIdentifier("results-page")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Change") { changing = true }
                    .foregroundStyle(Theme.text(colour))
                    .accessibilityIdentifier("results-change")
                if !model.readOnly, !filter.isEmpty, keptName == nil {
                    Button("Keep") {
                        name = String(filter.words.prefix(40))
                        naming = true
                    }
                    .foregroundStyle(Theme.text(colour))
                    .accessibilityIdentifier("results-keep")
                }
            }
        }
        .sheet(isPresented: $changing) {
            FilterPage(start: filter, onShow: { filter = $0; keptName = nil }, onKeep: { keptName = $0.name })
        }
        .alert("Keep as a shelf", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let made = model.keepFilter(filter, name: name) { keptName = made.name }
            }
        } message: {
            Text("The shelf shows on the main screen with the books that fit, always up to date.")
        }
    }
}
