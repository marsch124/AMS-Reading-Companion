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
                    ForEach(model.data.shelves()) { shelf in
                        ShelfRow(shelf: shelf, coverWidth: coverWidth)
                    }
                }
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("shelf-list")
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
                Button { model.addShown = true } label: {
                    ControlMarkView(.add, size: 20)
                }
                .help("Add a book")
                .accessibilityLabel("Add a book")
                .accessibilityIdentifier("add-book")
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

/// Every book of one shelf, as a grid of covers with their titles.
struct ShelfAllView: View {
    @EnvironmentObject private var model: ReadingModel
    let shelfID: String

    var body: some View {
        let shelf = model.data.shelves().first { $0.id == shelfID }
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 10, alignment: .top)], spacing: 12) {
                ForEach(shelf?.books ?? []) { book in
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
            .padding(12)
        }
        .navigationTitle(shelf?.title ?? "Shelf")
        .accessibilityIdentifier("shelf-all-\(shelfID)")
    }
}
