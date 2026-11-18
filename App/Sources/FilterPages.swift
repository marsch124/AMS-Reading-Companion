import AMSIcons
import ReadingCore
import SwiftUI

/// The row of small menus of the big filter: Store, Kind, Language, Status and More (stars, bought, finished,
/// tags, lock-free). Every choice is a tick in its menu. Inside one menu a book needs ONE of the ticks; across
/// menus it needs all of them. A menu only lists what the shelf has.
struct FilterMenus: View {
    @EnvironmentObject private var model: ReadingModel
    @Binding var filter: BookFilter

    private let colour = "sea"
    private let stores: [BookStore] = [.kobo, .kindle, .apple, .own]
    private let kinds: [BookKind] = [.ebook, .audiobook, .pdf]

    var body: some View {
        let owned = model.data.owned
        ChipFlow {
            pill(storeTitle, on: !filter.stores.isEmpty, id: "store") {
                ForEach(stores, id: \.self) { store in
                    let count = owned.filter { $0.copies.contains { $0.store == store } }.count
                    if count > 0 { tick("\(store.name) (\(count))", \.stores, store, "store-\(store.rawValue)") }
                }
            }
            pill(kindTitle, on: !filter.kinds.isEmpty, id: "kind") {
                ForEach(kinds, id: \.self) { kind in
                    let count = owned.filter { $0.copies.contains { $0.kind == kind } }.count
                    if count > 0 { tick("\(BookFilter.kindName(kind)) (\(count))", \.kinds, kind, "kind-\(kind.rawValue)") }
                }
            }
            pill(languageTitle, on: !filter.languages.isEmpty, id: "language") {
                ForEach(LibraryData.languages(in: owned), id: \.code) { language in
                    tick("\(BookLanguage.name(language.code)) (\(language.count))", \.languages, language.code, "language-\(language.code)")
                }
                let unknown = owned.filter { $0.language == nil }.count
                if unknown > 0 { tick("Not known (\(unknown))", \.languages, "", "language-unknown") }
            }
            pill(statusTitle, on: !filter.states.isEmpty, id: "status") {
                ForEach(ShelfState.allCases, id: \.self) { state in
                    tick(state.name, \.states, state, "state-\(state.rawValue)")
                }
            }
            pill(moreCount == 0 ? "More" : "More · \(moreCount)", on: moreCount > 0, id: "more") { more }
            if !filter.isEmpty {
                Button { filter = BookFilter() } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text(colour))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter-clear")
            }
        }
    }

    // MARK: More: stars, bought, finished, tags, lock-free

    @ViewBuilder
    private var more: some View {
        Menu("Your stars") {
            ForEach([3, 4, 5, 0], id: \.self) { stars in
                Toggle(stars == 0 ? "None yet" : (stars == 5 ? "5" : "\(stars) or more"), isOn: Binding(
                    get: { filter.stars == stars },
                    set: { filter.stars = $0 ? stars : nil }))
                    .accessibilityIdentifier("filter-stars-\(stars)")
            }
        }
        let bought = model.data.boughtYears()
        if !bought.isEmpty {
            Menu("Bought") {
                ForEach(bought.prefix(3), id: \.self) { year in
                    tick(String(year), \.boughtYears, year, "bought-\(year)")
                }
                if bought.count > 3, let before = bought.prefix(3).last {
                    Toggle("Earlier", isOn: Binding(
                        get: { filter.boughtBefore != nil },
                        set: { filter.boughtBefore = $0 ? before : nil }))
                        .accessibilityIdentifier("filter-bought-earlier")
                }
            }
        }
        let finished = model.data.finishedYears()
        if !finished.isEmpty {
            Menu("Finished") {
                ForEach(finished.prefix(5), id: \.self) { year in
                    tick(String(year), \.finishedYears, year, "finished-\(year)")
                }
            }
        }
        let tags = model.data.allTags()
        if !tags.isEmpty {
            Menu("Tags") {
                ForEach(tags, id: \.tag) { tag in
                    let key = LibraryData.tagKey(tag.tag)
                    tick("\(tag.tag) (\(tag.count))", \.tags, key, "tag-\(key)")
                }
            }
        }
        if model.data.owned.contains(where: \.isLockFree) {
            Toggle("Lock-free", isOn: $filter.lockFree)
                .accessibilityIdentifier("filter-lockfree")
        }
    }

    private var moreCount: Int {
        (filter.stars == nil ? 0 : 1) + filter.boughtYears.count + (filter.boughtBefore == nil ? 0 : 1)
            + filter.finishedYears.count + filter.tags.count + (filter.lockFree ? 1 : 0)
    }

    // MARK: What a menu's button says

    /// The first choice by name, and "+1" for each further one; the group's name when nothing is ticked.
    private func title(_ group: String, _ chosen: [String]) -> String {
        guard let first = chosen.first else { return group }
        return chosen.count == 1 ? first : "\(first) +\(chosen.count - 1)"
    }

    private var storeTitle: String { title("Store", stores.filter(filter.stores.contains).map(\.name)) }
    private var kindTitle: String { title("Kind", kinds.filter(filter.kinds.contains).map(BookFilter.kindName)) }
    private var languageTitle: String {
        title("Language", filter.languages.sorted().map { $0.isEmpty ? "Not known" : BookLanguage.name($0) })
    }
    private var statusTitle: String { title("Status", ShelfState.allCases.filter(filter.states.contains).map(\.name)) }

    // MARK: Pieces

    /// One menu: an outline with the group's name, or full colour with the choice once something is ticked.
    private func pill<Items: View>(_ title: String, on: Bool, id: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            #if os(iOS)
            // iPhone and iPad: the menu stays open, so several ticks go in one visit. (The Mac has no such choice.)
            items().menuActionDismissBehavior(.disabled)
            #else
            items()
            #endif
        } label: {
            HStack(spacing: 4) {
                Text(title)
                ControlMarkView(.chevron, size: 10, colour: on ? Color.white : Theme.text(colour))
                    .rotationEffect(.degrees(90))
            }
            .font(.subheadline)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(on ? Color.white : Theme.text(colour))
            .background(Capsule().fill(on ? Theme.fill(colour) : Color.clear))
            .overlay(Capsule().stroke(Theme.text(colour).opacity(on ? 0 : 0.45), lineWidth: 1))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityIdentifier("filter-menu-\(id)")
    }

    /// One tick in a menu: in or out of a group's choices.
    private func tick<T: Hashable>(_ title: String, _ group: WritableKeyPath<BookFilter, Set<T>>, _ value: T, _ id: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { filter[keyPath: group].contains(value) },
            set: { on in
                if on { filter[keyPath: group].insert(value) } else { filter[keyPath: group].remove(value) }
            }))
            .accessibilityIdentifier("filter-\(id)")
    }
}

/// The big filter: every book of the shelf as covers, with the menus above them. The books change at once with
/// every tick. "Keep" makes the filter a shelf of the owner's own.
struct FilterResultsPage: View {
    @EnvironmentObject private var model: ReadingModel
    @State var filter: BookFilter
    @State private var naming = false
    @State private var name = ""
    @State private var keptName: String?
    @AppStorage(CoverWall.key) private var wall = false

    private let colour = "sea"

    var body: some View {
        let books = model.data.books(matching: filter)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                FilterMenus(filter: $filter)
                Text(countLine(books.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("results-count")
                if let keptName {
                    Text("Kept as the shelf “\(keptName)”. It is on the main screen.")
                        .font(.footnote)
                        .foregroundStyle(Theme.text(colour))
                        .accessibilityIdentifier("results-kept")
                }
                if wall {
                    CoverWall(books: books, colour: colour).padding(.horizontal, -12)
                } else {
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
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("All books")
        .accessibilityIdentifier("results-page")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { WallToggle(wall: $wall, colour: colour) }
            ToolbarItem(placement: .primaryAction) {
                if !model.readOnly, !filter.isEmpty, keptName == nil {
                    Button("Keep") {
                        name = String(filter.words.prefix(40))
                        naming = true
                    }
                    .foregroundStyle(Theme.text(colour))
                    .help("Keep this filter as a shelf of your own")
                    .accessibilityIdentifier("results-keep")
                }
            }
        }
        .onChange(of: filter) { _, _ in keptName = nil }
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

    /// "42 of 469 books"; with Wish ticked the wishes come along, so only "42 books".
    private func countLine(_ found: Int) -> String {
        let all = model.data.owned.count
        if found == 0 { return "No book fits." }
        if filter.isEmpty || filter.states.contains(.wish) { return found == 1 ? "1 book" : "\(found) books" }
        return "\(found) of \(all) books"
    }
}

/// A filter that was kept as a shelf: its name, its choices (the same menus), or away with it.
struct KeptShelfPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let kept: SavedFilter
    @State private var filter = BookFilter()
    @State private var name = ""
    @State private var loaded = false
    @State private var askRemove = false

    private let colour = "sea"

    var body: some View {
        let found = model.data.books(matching: filter).count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name of the shelf", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("filter-name")
                    FilterMenus(filter: $filter)
                    Text(filter.isEmpty ? "Tick at least one choice." : (found == 1 ? "1 book fits." : "\(found) books fit."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("kept-count")
                    Button { askRemove = true } label: {
                        Text("Remove this shelf")
                            .foregroundStyle(Theme.text("red"))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("filter-remove")
                    .confirmationDialog("Remove this shelf? Its books stay on your shelf.", isPresented: $askRemove,
                                        titleVisibility: .visible) {
                        Button("Remove", role: .destructive) {
                            model.removeKeptFilter(kept.id)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Change shelf")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("filter-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.changeKeptFilter(kept.id, name: name, filter: filter)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .disabled(filter.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("filter-save")
                }
            }
        }
        .accessibilityIdentifier("kept-page")
        .onAppear {
            guard !loaded else { return }
            loaded = true
            filter = kept.filter
            name = kept.name
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(width: 480, height: 360)
        #endif
    }
}
