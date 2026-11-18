import AMSIcons
import ReadingCore
import SwiftUI

/// Where a tap on the main screen leads.
enum Route: Hashable {
    case book(String)
    case shelf(String)
    /// Every book of one author (0.6).
    case author(String)
    /// Every part of one series (0.6).
    case series(String)
    /// The books that fit a filter (0.6).
    case results(BookFilter)
}

/// Opens a page on the main screen's stack from anywhere below it (also from the book shown beside the shelves).
private struct OpenRouteKey: EnvironmentKey {
    static let defaultValue: ((Route) -> Void)? = nil
}

/// On a wide screen a tap on a cover does not push a page: it shows the book in the part on the right.
private struct OpenBookKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

private struct SelectedBookKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Set on a wide screen: shows a book beside the shelves.
    var openBook: ((String) -> Void)? {
        get { self[OpenBookKey.self] }
        set { self[OpenBookKey.self] = newValue }
    }

    var openRoute: ((Route) -> Void)? {
        get { self[OpenRouteKey.self] }
        set { self[OpenRouteKey.self] = newValue }
    }

    /// The book shown beside the shelves, so its cover can carry a frame.
    var selectedBook: String? {
        get { self[SelectedBookKey.self] }
        set { self[SelectedBookKey.self] = newValue }
    }
}

/// A tap that leads to a book: beside the shelves on a wide screen, else as a page of its own.
/// `pushes` is for a link that sits on a page which was itself opened without a route (a search result's page).
struct BookLink<Label: View>: View {
    @Environment(\.openBook) private var openBook
    let id: String
    var pushes = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        if let openBook {
            Button { openBook(id) } label: { label() }
        } else if pushes {
            NavigationLink { BookPage(bookID: id) } label: { label() }
        } else {
            NavigationLink(value: Route.book(id)) { label() }
        }
    }
}

/// The main screen: the shelves, top to bottom, each a coloured heading over a row of covers that scrolls sideways.
/// On an iPad and on the Mac, in a window 760 points wide or more, the book that was tapped shows beside them.
struct RootView: View {
    @EnvironmentObject private var model: ReadingModel
    @State private var path: [Route] = []
    /// Wide screens: the book shown on the right. Kept while the app is open, not saved.
    @State private var selected: String?
    @State private var changesShown = false

    static let wideFrom: CGFloat = 760

    #if os(macOS)
    private let coverWidth: CGFloat = 92
    #else
    private let coverWidth: CGFloat = 78
    #endif

    var body: some View {
        GeometryReader { window in
            let wide = window.size.width >= Self.wideFrom
            HStack(spacing: 0) {
                shelves
                    .environment(\.openBook, wide ? { selected = $0 } : nil)
                    .environment(\.selectedBook, wide ? selected : nil)
                    .environment(\.openRoute, { path.append($0) })
                if wide {
                    Divider()
                    bookPane
                        .environment(\.openRoute, { path.append($0) })
                        .frame(width: min(440, max(340, window.size.width * 0.38)))
                }
            }
            .task(id: wide) { settle(wide: wide) }
            // A tap on the widget or in the device's search while the app is open.
            .onChange(of: model.startBook) { _, id in
                if id != nil { settle(wide: wide) }
            }
        }
        .sheet(isPresented: $model.settingsShown) { SettingsView() }
        .sheet(isPresented: $model.searchShown) { SearchView() }
        .sheet(isPresented: $model.addShown) { AddBookPage() }
        .sheet(isPresented: $model.scanShown) { ScanView() }
        .sheet(isPresented: $model.yearShown) { YearPage(start: model.yearOnAuthors ? .authors : (model.yearOnNumbers ? .numbers : .year)) }
        .sheet(isPresented: $model.notesShown) { NotesPage() }
        .sheet(item: $model.noteDraft) { NoteEditPage(draft: $0) }
        .sheet(isPresented: $changesShown) { ChangesPage() }
    }

    /// What a start argument asked for, and on a wide screen a first book on the right so that part is not empty.
    private func settle(wide: Bool) {
        if let id = model.startBook {
            model.startBook = nil
            if wide { selected = id } else { path = [.book(id)] }
        }
        if let id = model.startShelf {
            model.startShelf = nil
            path = [.shelf(id)]
        }
        // For pictures: `-filter` starts on the big filter.
        if model.filterShown {
            model.filterShown = false
            path = [.results(BookFilter())]
        }
        // For pictures: `-page author`, `-page series`, `-page results`, `-page changes` start on that page.
        if let page = model.startPage {
            switch page {
            case "author": path = [.author(model.data.noteBook?.author ?? model.data.owned.first?.author ?? "")]
            case "series": path = [.series(model.data.owned.first { $0.series != nil }?.series ?? "")]
            case "results":
                if let kept = model.data.savedFilters.first { path = [.results(kept.filter)] }
            case "changes": changesShown = true
            default: break
            }
            if ["author", "series", "results", "changes"].contains(page) { model.startPage = nil }
        }
        if wide, selected == nil {
            selected = model.data.shelf("reading")?.books.first?.id
        }
    }

    /// The right part of a wide screen: the page of the book that was tapped.
    private var bookPane: some View {
        Group {
            if let id = selected, model.data.book(id) != nil {
                BookPage(bookID: id)
                    .id(id)
                    .environment(\.openBook, { selected = $0 })
            } else {
                Text("Tap a cover and the book shows here.")
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("book-pane-empty")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("book-pane")
    }

    private var shelves: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.readOnly { newerNote }
                    if model.data.ownedAll.isEmpty { emptyNote }
                    if model.data.shows(.finished), let done = model.justFinished { FinishedCard(book: done).id(done.id) }
                    let ideas = model.data.whatNext()
                    if !ideas.isEmpty, model.data.shows(.whatNext) { WhatNextCard(ideas: ideas) }
                    if !model.data.owned.isEmpty, model.data.shows(.notes) { notesLine }
                    if model.data.shows(.quote), let quote = model.data.quoteOfDay() { QuoteLine(note: quote) }
                    ForEach(model.data.mainShelves()) { shelf in
                        ShelfRow(shelf: shelf, coverWidth: coverWidth)
                    }
                    if model.data.shows(.changes), let last = model.data.changes.first { changesLine(last) }
                }
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("shelf-list")
            // The Mac would draw a keyboard-focus frame around the first shelf heading.
            .focusEffectDisabled()
            .navigationTitle("My Books")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .book(let id): BookPage(bookID: id)
                case .shelf(let id): ShelfAllView(shelfID: id)
                case .author(let name): AuthorPage(author: name)
                case .series(let name): SeriesPage(series: name)
                case .results(let filter): FilterResultsPage(filter: filter)
                }
            }
        }
    }

    /// The big filter over the whole shelf.
    private var filterButton: some View {
        // The filter is a page of the shelves' own stack: every book, with the menus above them.
        Button { path.append(.results(BookFilter())) } label: {
            AppMarkView(.filter, size: 20)
        }
        .help("Filter: narrow the whole shelf down")
        .accessibilityLabel("Filter")
        .accessibilityIdentifier("open-filter")
    }

    /// The pen: a new reading note for the book being read. With no book to write on it opens the notebook.
    private var penButton: some View {
        Button {
            if let book = model.data.noteBook ?? model.data.upNextBooks.first ?? model.data.owned.first, !model.readOnly {
                model.noteDraft = NoteDraft(bookID: book.id)
            } else {
                model.notesShown = true
            }
        } label: {
            AppMarkView(.compose, size: 20, colour: Theme.text("orange"))
                .padding(.leading, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Write a reading note")
        .accessibilityLabel("Write a reading note")
        .accessibilityIdentifier("new-note")
    }

    /// One line under "What next?": the notebook with how many notes it holds, and the pen for a new note.
    private var notesLine: some View {
        let notes = model.data.shownNotes
        let todo = model.data.openTodos
        return HStack(alignment: .center, spacing: 4) {
            Button { model.notesShown = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(notes.isEmpty ? "Reading notes" : "Reading notes · \(notes.count)")
                        .font(.headline)
                        .foregroundStyle(Theme.text("orange"))
                        .lineLimit(1)
                        .fixedSize()
                    if !todo.isEmpty {
                        Text("\(todo.count) to do")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.text("red"))
                            .lineLimit(1)
                            .fixedSize()
                            .accessibilityIdentifier("notes-todo-count")
                    }
                    Text(notes.first?.text ?? "Nothing noted yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if !notes.isEmpty {
                        ControlMarkView(.chevron, size: 14, colour: Theme.text("orange"))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("open-notes")
            penButton
        }
        .padding(.horizontal, 12)
    }

    /// A tiny line at the very bottom: what the latest read of a store's list brought and took away.
    private func changesLine(_ last: ChangeEntry) -> some View {
        var parts: [String] = []
        if last.cameCount > 0 { parts.append("\(last.cameCount) came") }
        if last.leftCount > 0 { parts.append("\(last.leftCount) left") }
        return Button { changesShown = true } label: {
            Text("\(last.storeName): \(parts.joined(separator: ", ")) · \(last.date.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityIdentifier("open-changes")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(iOS)
        // On iPhone and iPad the filter stands on the left, so the four on the right stay where they were and the
        // title keeps its room. (The pen stands on the "Reading notes" line: six buttons squeezed the title out.)
        ToolbarItem(placement: .topBarLeading) {
            filterButton
        }
        #endif
        ToolbarItemGroup(placement: .primaryAction) {
            #if os(macOS)
            filterButton
            #endif
            Button { model.searchShown = true } label: {
                AppMarkView(.search, size: 20)
            }
            .help("Search: do I own it?")
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("Search")
            .accessibilityIdentifier("open-search")

            Button { model.yearOnNumbers = false; model.yearOnAuthors = false; model.yearShown = true } label: {
                AppMarkView(.calendar, size: 20)
            }
            .help("Your reading: the year in books, and the numbers")
            .accessibilityLabel("Your reading")
            .accessibilityIdentifier("open-year")

            if !model.readOnly {
                #if os(iOS)
                // On iPhone and iPad the plus offers two ways in: by hand, or by the barcode on a printed book.
                Menu {
                    Button("Add a book") { model.addShown = true }
                        .accessibilityIdentifier("add-book")
                    Button("Scan a barcode") { model.scanShown = true }
                        .accessibilityIdentifier("open-scan")
                } label: {
                    ControlMarkView(.add, size: 20)
                }
                .accessibilityLabel("Add a book")
                .accessibilityIdentifier("add-menu")
                #else
                Button { model.addShown = true } label: {
                    ControlMarkView(.add, size: 20)
                }
                .help("Add a book")
                .accessibilityLabel("Add a book")
                .accessibilityIdentifier("add-book")
                #endif
            }

            Button { model.settingsShown = true } label: {
                ControlMarkView(.settings, size: 20)
            }
            .help("Settings, How it works, What's new")
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settingsButton")
        }
    }

    private var emptyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your shelf is empty")
                .font(.headline)
                .foregroundStyle(Theme.text("purple"))
            if model.isMac {
                Text(model.readingLists
                     ? "Reading your book lists from Apple Books, Kindle and Kobo…"
                     : "No books were found in Apple Books, Kindle or Kobo on this Mac. Settings shows what each list said.")
            } else {
                Text("Open AMS Reading on your Mac once. It reads your book lists there, and the books appear here through iCloud.")
            }
        }
        .font(.subheadline)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
        .accessibilityIdentifier("shelf-empty")
    }

    private var newerNote: some View {
        Text("This shelf was saved by a newer version of AMS Reading. You can look at everything here; to change things, update the app on this device.")
            .font(.subheadline)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .accessibilityIdentifier("newer-note")
    }
}

/// One shelf: its heading (tap it to see every book of the shelf) and its covers.
struct ShelfRow: View {
    let shelf: Shelf
    let coverWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            NavigationLink(value: Route.shelf(shelf.id)) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(shelf.title)
                        .font(.headline)
                        .foregroundStyle(Theme.text(shelf.colour))
                    if let note = shelf.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if shelf.books.count > 3 {
                        ControlMarkView(.chevron, size: 14, colour: Theme.text(shelf.colour))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(shelf.books.isEmpty)
            .padding(.horizontal, 12)
            .accessibilityIdentifier("shelf-\(shelf.id)")

            if !shelf.books.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 8) {
                        ForEach(shelf.books) { book in
                            BookTile(book: book, width: coverWidth)
                                .accessibilityIdentifier("book-\(shelf.id)-\(book.id)")
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

/// A cover with its store marks under it. A tap goes to the book's page.
struct BookTile: View {
    let book: Book
    let width: CGFloat
    @Environment(\.selectedBook) private var chosen

    var body: some View {
        BookLink(id: book.id) {
            VStack(alignment: .leading, spacing: 3) {
                CoverView(book: book, width: width)
                    // A started book carries a thin bar along the bottom of its cover: how far it is read.
                    .overlay(alignment: .bottom) {
                        if let done = LibraryData.coverProgress(book) {
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.black.opacity(0.45))
                                Rectangle().fill(Color.white).frame(width: max(2, width * done))
                            }
                            .frame(width: width, height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .accessibilityLabel("\(Int((done * 100).rounded())) percent read")
                            .accessibilityIdentifier("cover-progress")
                        }
                    }
                    // The book shown beside the shelves carries a purple frame.
                    .overlay(RoundedRectangle(cornerRadius: max(2, width * 0.05) + 2, style: .continuous)
                        .strokeBorder(Theme.text("purple"), lineWidth: 2)
                        .padding(-3)
                        .opacity(chosen == book.id ? 1 : 0))
                StoreMarks(book: book)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.title), \(book.author)")
    }
}

/// "What next?": one suggestion above the shelves. "Another" shows the next idea.
struct WhatNextCard: View {
    @EnvironmentObject private var model: ReadingModel
    let ideas: [ReadSuggestion]
    @State private var index = 0
    /// "Surprise me": a book picked by chance, shown in place of the idea until "Another" is pressed.
    @State private var surprise: String?

    var body: some View {
        let chance = surprise.flatMap { model.data.book($0) }
        let idea = chance.map { ReadSuggestion(book: $0, reason: "A surprise from the books you have not started") }
            ?? ideas[index % ideas.count]
        HStack(alignment: .top, spacing: 10) {
            BookLink(id: idea.book.id) {
                HStack(alignment: .top, spacing: 10) {
                    CoverView(book: idea.book, width: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What next?")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.text("purple"))
                        Text(idea.book.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(idea.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        StoreMarks(book: idea.book)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("whatnext-card")
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                if ideas.count > 1 || surprise != nil {
                    Button("Another") {
                        if surprise != nil { surprise = nil } else { index += 1 }
                    }
                    .accessibilityIdentifier("whatnext-another")
                }
                Button("Surprise me") { surprise = model.surprise()?.id }
                    .accessibilityIdentifier("whatnext-surprise")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.text("purple"))
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
    }
}

/// Every book of one shelf, as a grid of covers with their titles. Three small menus narrow the shelf down
/// (one store, to read or to listen) and put it in another order.
struct ShelfAllView: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let shelfID: String
    @State private var filter = ShelfFilter()
    // For pictures: `-order` and `-length` start with that page open.
    @State private var ordering = ProcessInfo.processInfo.arguments.contains("-order")
    @State private var settingLength = ProcessInfo.processInfo.arguments.contains("-length")
    @State private var changingKept = false
    @AppStorage(CoverWall.key) private var wall = false
    @State private var selecting = false
    @State private var ticked: Set<String> = []

    var body: some View {
        let shelf = model.data.shelf(shelfID)
        let all = shelf?.books ?? []
        let books = filter.apply(to: all)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                filterRow(colour: shelf?.colour ?? "grey", languages: LibraryData.languages(in: all))
                if !filter.isPlain {
                    Text(books.isEmpty ? "No book of this shelf fits." : "Showing \(books.count) of \(all.count).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("filter-count")
                }
                if wall {
                    CoverWall(books: books, colour: shelf?.colour ?? "grey").padding(.horizontal, -12)
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
                            .accessibilityIdentifier("all-\(book.id)")
                            .selectableCover(book.id)
                        }
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle(shelf?.title ?? "Shelf")
        .accessibilityIdentifier("shelf-all-\(shelfID)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { WallToggle(wall: $wall, colour: shelf?.colour ?? "grey") }
            ToolbarItem(placement: .primaryAction) {
                if !model.readOnly, shelfID == "upnext" {
                    Button("Change order") { ordering = true }
                        .foregroundStyle(Theme.text("indigo"))
                        .accessibilityIdentifier("upnext-order")
                } else if !model.readOnly, shelfID.hasPrefix("series-"), shelf != nil {
                    Button("Set length") { settingLength = true }
                        .foregroundStyle(Theme.text("green"))
                        .accessibilityIdentifier("series-length")
                } else if !model.readOnly, model.data.keptFilter(shelfID: shelfID) != nil {
                    Button("Change") { changingKept = true }
                        .foregroundStyle(Theme.text("sea"))
                        .accessibilityIdentifier("kept-change")
                }
            }
            if shelfID.hasPrefix("series-"), let name = shelf?.title {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(value: Route.series(name)) { Text("All parts") }
                        .accessibilityIdentifier("series-all-parts")
                }
            }
        }
        .selectMode(books: books, colour: shelf?.colour ?? "grey", selecting: $selecting, ids: $ticked)
        .sheet(isPresented: $ordering) { UpNextOrderPage() }
        .sheet(isPresented: $settingLength) { SeriesLengthPage(name: shelf?.title ?? "") }
        // A kept filter that was removed has no page any more: go back.
        .onChange(of: shelfID.hasPrefix("saved-") && shelf == nil) { _, gone in
            if gone { dismiss() }
        }
        .sheet(isPresented: $changingKept) {
            if let kept = model.data.keptFilter(shelfID: shelfID) { KeptShelfPage(kept: kept) }
        }
    }

    /// The menus in one row where they fit, else the language menu on a row of its own.
    @ViewBuilder
    private func filterRow(colour: String, languages: [(code: String, count: Int)]) -> some View {
        if languages.isEmpty {
            menus(colour: colour)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    menus(colour: colour)
                    languageMenu(languages, colour: colour)
                }
                VStack(alignment: .leading, spacing: 4) {
                    menus(colour: colour)
                    languageMenu(languages, colour: colour)
                }
            }
        }
    }

    private func languageMenu(_ languages: [(code: String, count: Int)], colour: String) -> some View {
        Picker("Language", selection: $filter.language) {
            Text("All languages").tag(String?.none)
            ForEach(languages, id: \.code) { language in
                Text("\(BookLanguage.name(language.code)) · \(language.count)").tag(String?.some(language.code))
            }
        }
        .accessibilityIdentifier("filter-language")
        .pickerStyle(.menu)
        .labelsHidden()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .tint(Theme.text(colour))
        .font(.subheadline)
    }

    private func menus(colour: String) -> some View {
        HStack(spacing: 6) {
            Picker("Store", selection: $filter.store) {
                Text("All stores").tag(BookStore?.none)
                ForEach([BookStore.kobo, .kindle, .apple, .own], id: \.self) { store in
                    Text(store.name).tag(BookStore?.some(store))
                }
            }
            .accessibilityIdentifier("filter-store")
            Picker("Kind", selection: $filter.kind) {
                Text("All kinds").tag(ShelfFilter.Kind.all)
                Text("To read").tag(ShelfFilter.Kind.read)
                Text("To listen").tag(ShelfFilter.Kind.listen)
            }
            .accessibilityIdentifier("filter-kind")
            Picker("Order", selection: $filter.order) {
                Text("Shelf order").tag(ShelfFilter.Order.shelf)
                Text("By title").tag(ShelfFilter.Order.title)
                Text("By author").tag(ShelfFilter.Order.author)
                Text("Newest first").tag(ShelfFilter.Order.newest)
            }
            .accessibilityIdentifier("filter-order")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .tint(Theme.text(colour))
        .font(.subheadline)
    }
}
