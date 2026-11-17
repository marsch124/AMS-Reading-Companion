import AMSIcons
import ReadingCore
import SwiftUI

/// Where a tap on the main screen leads.
enum Route: Hashable {
    case book(String)
    case shelf(String)
}

/// The main screen: the shelves, top to bottom, each a coloured heading over a row of covers that scrolls sideways.
struct RootView: View {
    @EnvironmentObject private var model: ReadingModel
    @State private var path: [Route] = []

    #if os(macOS)
    private let coverWidth: CGFloat = 92
    #else
    private let coverWidth: CGFloat = 78
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.readOnly { newerNote }
                    if model.data.owned.isEmpty { emptyNote }
                    let ideas = model.data.whatNext()
                    if !ideas.isEmpty { WhatNextCard(ideas: ideas) }
                    ForEach(model.data.shelves()) { shelf in
                        ShelfRow(shelf: shelf, coverWidth: coverWidth)
                    }
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
                }
            }
        }
        .sheet(isPresented: $model.settingsShown) { SettingsView() }
        .sheet(isPresented: $model.searchShown) { SearchView() }
        .sheet(isPresented: $model.addShown) { AddBookPage() }
        .sheet(isPresented: $model.scanShown) { ScanView() }
        .onAppear {
            if let id = model.startBook {
                model.startBook = nil
                path = [.book(id)]
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.searchShown = true } label: {
                AppMarkView(.search, size: 20)
            }
            .help("Search: do I own it?")
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("Search")
            .accessibilityIdentifier("open-search")

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

    var body: some View {
        NavigationLink(value: Route.book(book.id)) {
            VStack(alignment: .leading, spacing: 3) {
                CoverView(book: book, width: width)
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
    let ideas: [ReadSuggestion]
    @State private var index = 0

    var body: some View {
        let idea = ideas[index % ideas.count]
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: Route.book(idea.book.id)) {
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
            if ideas.count > 1 {
                Button("Another") { index += 1 }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text("purple"))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("whatnext-another")
            }
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
    let shelfID: String
    @State private var filter = ShelfFilter()

    var body: some View {
        let shelf = model.data.shelf(shelfID)
        let all = shelf?.books ?? []
        let books = filter.apply(to: all)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                filterRow(colour: shelf?.colour ?? "grey")
                if !filter.isPlain {
                    Text(books.isEmpty ? "No book of this shelf fits." : "Showing \(books.count) of \(all.count).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("filter-count")
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
                        .accessibilityIdentifier("all-\(book.id)")
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle(shelf?.title ?? "Shelf")
        .accessibilityIdentifier("shelf-all-\(shelfID)")
    }

    private func filterRow(colour: String) -> some View {
        HStack(spacing: 6) {
            Picker("Store", selection: $filter.store) {
                Text("All stores").tag(BookStore?.none)
                ForEach([BookStore.kobo, .kindle, .apple, .own], id: \.self) { store in
                    Text(store.name).tag(BookStore?.some(store))
                }
            }
            .accessibilityIdentifier("filter-store")
            Picker("Kind", selection: $filter.kind) {
                Text("Read or listen").tag(ShelfFilter.Kind.all)
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
            Spacer(minLength: 0)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Theme.text(colour))
        .font(.subheadline)
    }
}
