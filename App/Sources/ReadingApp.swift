import CoreSpotlight
import ReadingCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
import WidgetKit
#endif

@main
struct ReadingApp: App {
    @StateObject private var model = ReadingModel()
    @StateObject private var covers = Covers()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        #if os(macOS)
        WindowGroup("AMS Reading Companion", id: "main") {
            root.frame(minWidth: 560, minHeight: 460)
        }
        .defaultSize(width: 920, height: 720)
        // One shelf, one window: no "New Window" in the File menu.
        .commands { CommandGroup(replacing: .newItem) {} }
        #else
        WindowGroup { root }
        #endif
    }

    private var root: some View {
        RootView()
            .environmentObject(model)
            .environmentObject(covers)
            .tint(Theme.text("purple"))
            .onAppear {
                covers.keep = { id, address in model.setCover(address, of: id) }
            }
            .onChange(of: phase) { _, now in
                if now == .active { model.cameForward() } else { model.saveNow() }
            }
            // A tap on the Home Screen widget.
            .onOpenURL { model.open(link: $0) }
            // A tap on a book in the device's own search.
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let id = SpotlightIndex.bookID(from: activity) { model.show(bookID: id) }
            }
    }
}

enum SendTarget: String { case apple, kobo, kindle }

/// A reading note on its way: a new one for a book, or one that exists and is being changed.
struct NoteDraft: Identifiable, Equatable {
    var bookID: String
    /// nil = a new note.
    var noteID: String?
    var id: String { noteID ?? "new-\(bookID)" }
}

/// What the screens share: the shelf, and everything that changes it.
@MainActor
final class ReadingModel: ObservableObject {
    @Published var data = LibraryData()
    /// A red line on the book page when opening or sending did not work.
    @Published var trouble: String?
    /// A calm line on the book page after a send worked.
    @Published var notice: String?
    @Published var settingsShown = false
    @Published var searchShown = false
    @Published var addShown = false
    @Published var scanShown = false
    /// "Your reading": the year in books and the numbers.
    @Published var yearShown = false
    /// For pictures: `-numbers` starts "Your reading" on its Numbers part.
    var yearOnNumbers = false
    /// For pictures: `-authors` opens Your reading on its Authors part.
    var yearOnAuthors = false
    /// The Mac only: what the last read of each store's list said when it gave no books.
    @Published var storeTrouble: [String: String] = [:]
    @Published var readingLists = false
    @Published var cloudOn = true
    /// A line in Settings after a Kindle list file was taken in.
    @Published var fileNote: String?
    /// For pictures: `-filter` starts on the big filter (0.6).
    var filterShown = false
    /// The notebook: every reading note (0.6).
    @Published var notesShown = false
    /// A note being written or changed, from anywhere in the app.
    @Published var noteDraft: NoteDraft?
    /// The book "Surprise me" picked last, so the next press gives another.
    var lastSurprise: String?
    /// For pictures: `-page author|series|results|changes` starts on that page (see RootView); `-page shelves|kinds` with `-settings`.
    var startPage: String?
    /// For pictures and screen tests: `-show <book id>` starts on that book's page.
    @Published var startBook: String?
    /// For pictures: `-shelf unread` starts on that shelf's page.
    @Published var startShelf: String?

    /// Made-up books for pictures and screen tests (`-sampleData`): nothing is read and nothing is saved.
    let sample: Bool
    private let store = LibraryStore()
    private var saveTask: Task<Void, Never>?
    /// A change is waiting to be written.
    private var unsaved = false
    private var lastRead = Date.distantPast
    private var askingAbout = Set<String>()

    var readOnly: Bool { data.isNewer }

    var canSend: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    var isMac: Bool { canSend }

    init() {
        let args = ProcessInfo.processInfo.arguments
        sample = args.contains("-sampleData")
        if sample {
            data = .sample
        } else {
            data = store.loadLocal() ?? LibraryData()
        }
        settingsShown = args.contains("-settings")
        searchShown = args.contains("-search")
        addShown = args.contains("-add")
        scanShown = args.contains("-scan")
        yearOnNumbers = args.contains("-numbers")
        yearOnAuthors = args.contains("-authors")
        yearShown = args.contains("-year") || yearOnNumbers || yearOnAuthors
        if let i = args.firstIndex(of: "-shelf"), i + 1 < args.count { startShelf = args[i + 1] }
        filterShown = args.contains("-filter")
        notesShown = args.contains("-notes")
        if let i = args.firstIndex(of: "-page"), i + 1 < args.count { startPage = args[i + 1] }
        if args.contains("-newnote"), let book = data.noteBook { noteDraft = NoteDraft(bookID: book.id) }
        // `-show Brass` starts on the page of the first book whose title holds that word.
        // (By title, not by id: the Mac takes an argument with a colon in it for a file to open and shows no window.)
        if let i = args.firstIndex(of: "-show"), i + 1 < args.count {
            let word = args[i + 1].lowercased()
            startBook = data.shown.first { $0.id == args[i + 1] || $0.title.lowercased().contains(word) }?.id
        }
        #if os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow(wait: true) }
        }
        #endif
        cameForward()
    }

    // MARK: Loading and saving

    /// The app came to the front: take in what other devices wrote, and on the Mac read the stores' lists.
    func cameForward() {
        guard !sample else { return }
        let store = self.store
        Task.detached(priority: .userInitiated) {
            let loaded = store.load()
            let cloud = store.cloudOn
            await MainActor.run {
                self.cloudOn = cloud
                if let loaded { self.data = LibraryData.merged(loaded, self.data) }
                self.takeSharedWishes()
                self.shareShelf()
                self.lookUpSeries()
                if self.isMac, Date().timeIntervalSince(self.lastRead) > 60 { self.readLists() }
            }
        }
    }

    func change(_ edit: (inout LibraryData) -> Void) {
        guard !readOnly else { return }
        let before = data
        edit(&data)
        guard data != before else { return }
        // What this version writes may hold things an older version would lose by saving.
        if data.format < LibraryData.currentFormat { data.format = LibraryData.currentFormat }
        guard !sample else { return }
        unsaved = true
        saveTask?.cancel()
        saveTask = Task { [store] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let snapshot = self.data
            self.unsaved = false
            let written = await Task.detached { store.save(snapshot) }.value
            self.data = LibraryData.merged(self.data, written)
            self.shareShelf()
        }
    }

    // MARK: Outside the app: a widget tap, a search tap

    /// Goes to a book's page from outside the app, closing whatever page lies on top.
    func show(bookID id: String) {
        guard data.book(id) != nil else { return }
        settingsShown = false; searchShown = false; addShown = false; scanShown = false; yearShown = false
        startBook = id
    }

    /// `amsreading://book/<id>`: what a tap on the Home Screen widget sends.
    func open(link url: URL) {
        let start = "amsreading://book/"
        let text = url.absoluteString
        guard text.hasPrefix(start), let id = String(text.dropFirst(start.count)).removingPercentEncoding else { return }
        show(bookID: id)
    }

    // MARK: The Share check and the widget (iPhone and iPad), the device's own search (everywhere)

    /// Gives the Share extension a small list of the shelf, the widget its books, and the device's search the titles.
    /// Everything stays on the device.
    private func shareShelf() {
        guard !sample else { return }
        let books = data.shown
        #if os(iOS)
        let entries = books.map { ShelfEntry(title: $0.title, author: $0.author, stores: $0.stores.map(\.name), wish: $0.wish) }
        func tile(_ book: Book) -> WidgetBook {
            WidgetBook(id: book.id, title: book.title, author: book.author, coverURL: book.coverURL, tint: book.title)
        }
        let idea = data.whatNext(limit: 1).first
        let snapshot = WidgetSnapshot(reading: (data.shelf("reading")?.books ?? []).prefix(3).map(tile),
                                      next: idea.map { tile($0.book) }, nextReason: idea?.reason)
        Task.detached(priority: .utility) {
            ShareFiles.writeIndex(entries)
            if WidgetFiles.read() != snapshot {
                WidgetFiles.write(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
        Task.detached(priority: .utility) { SpotlightIndex.update(books) }
    }

    private func takeSharedWishes() {
        #if os(iOS)
        guard !sample, !readOnly else { return }
        for wish in ShareFiles.takeWishes() { add(title: wish.title, author: wish.author, store: nil) }
        #endif
    }

    // MARK: What a catalogue knows about the series

    private var seriesTask: Task<Void, Never>?

    /// Asks a public catalogue how long each series on the shelf is. Once per series, again after 60 days.
    func lookUpSeries() {
        guard !sample, !readOnly, seriesTask == nil else { return }
        let stale = Date().addingTimeInterval(-60 * 86_400)
        let wanted = data.seriesNames().filter { (data.seriesInfo(for: $0.name)?.checked ?? .distantPast) < stale }.prefix(40)
        guard !wanted.isEmpty else { return }
        seriesTask = Task {
            var answers: [(String, SeriesInfo)] = []
            for entry in wanted {
                let answer = await SeriesLookup.ask(series: entry.name, author: entry.author, knownTitle: entry.title)
                // The catalogue could not be reached: stop, note nothing, and try again another time.
                guard answer.answered else { break }
                answers.append((entry.name, SeriesInfo(total: answer.found?.total, volumes: answer.found?.volumes ?? [])))
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // Everything in one go: one change, one save.
            if !answers.isEmpty {
                self.change { data in
                    for (name, info) in answers { data.setSeries(info, for: name) }
                }
            }
            self.seriesTask = nil
        }
    }

    /// The app is leaving the front, or quitting: write a waiting change now, not half a second later.
    func saveNow(wait: Bool = false) {
        guard unsaved, !sample, !readOnly else { return }
        saveTask?.cancel()
        unsaved = false
        let snapshot = data
        let store = self.store
        if wait {
            _ = store.save(snapshot)
        } else {
            Task.detached { _ = store.save(snapshot) }
        }
    }

    // MARK: The stores' lists (Mac)

    func readLists() {
        #if os(macOS)
        guard !sample, !readingLists, !readOnly else { return }
        readingLists = true
        lastRead = Date()
        Task.detached(priority: .userInitiated) {
            let apple = Collector.readApple()
            let kindle = Collector.readKindle()
            let kobo = Collector.readKobo()
            await MainActor.run {
                self.took(apple, source: .apple, key: "apple", complete: true)
                self.took(kindle, source: .kindle, key: "kindle", complete: false)
                self.took(kobo, source: .kobo, key: "kobo", complete: true)
                // A guessed language where no store tells one, fixed finishing days, a clean Up next list.
                self.change { $0.tidy() }
                self.readingLists = false
            }
        }
        #endif
    }

    private func took(_ read: StoreRead, source: CopySource, key: String, complete: Bool) {
        storeTrouble[key] = read.trouble
        let count = read.books.filter { !$0.isSample }.count
        guard count > 0 else { return }
        change { data in
            let first = data.imports[key] == nil
            let summary = data.take(read.books, source: source, complete: complete)
            data.noteChange(summary, store: key, first: first)
            // Kindle's Mac list is only its latest sync, so its count is "books on the shelf", not "books in the list".
            let shown = source == .kindle
                ? data.ownedAll.filter { $0.copies.contains { $0.store == .kindle } }.count
                : count
            if data.imports[key]?.count != shown || !Calendar.current.isDateInToday(data.imports[key]?.date ?? .distantPast) {
                data.imports[key] = ImportNote(date: Date(), count: shown)
            }
        }
    }

    /// Settings › Import Kindle list: a one-time file with the whole Kindle library.
    func importKindleFile(_ url: URL) {
        guard !readOnly else {
            fileNote = "This device has an older version of AMS Reading, so the file cannot be taken in here. Update the app first."
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var books: [ImportedBook]
        var more = ""
        if url.pathExtension.lowercased() == "pdf" {
            // The page "Manage Your Content and Devices" at Amazon, saved as a PDF.
            guard let text = PDFText.text(of: url) else {
                fileNote = "That PDF could not be read."
                return
            }
            guard KindlePDFText.looksRight(text) else {
                fileNote = "That PDF is not Amazon's book list. Save the page “Manage Your Content and Devices” (Books) as a PDF."
                return
            }
            books = KindlePDFText.parse(text)
            if let counts = KindlePDFText.counts(text), counts.total > counts.shown {
                more = " Amazon shows \(counts.shown) of your \(counts.total) books per page: save its next page as a PDF too."
            }
        } else {
            guard let bytes = try? Data(contentsOf: url) else {
                fileNote = "That file could not be read."
                return
            }
            books = KindleListFile.parse(bytes)
        }
        guard !books.isEmpty else {
            fileNote = "No books found in that file. It can be Amazon's book list saved as a PDF, or a list with a title and an author per book."
            return
        }
        var summary = ImportSummary()
        change { data in
            summary = data.take(books, source: .kindle, complete: false)
            let shown = data.ownedAll.filter { $0.copies.contains { $0.store == .kindle } }.count
            data.imports["kindle"] = ImportNote(date: Date(), count: shown)
        }
        fileNote = "\(books.count) Kindle books in the file: \(summary.added) new on the shelf, \(books.count - summary.added) were already there." + more
    }

    // MARK: What the owner does

    func setStatus(_ status: ReadStatus, of id: String) {
        change { $0.setStatus(status, of: id) }
    }

    @discardableResult
    func add(title: String, author: String, store: BookStore?) -> Book? {
        var book: Book?
        change { book = $0.add(title: title, author: author, store: store) }
        return book
    }

    func remove(_ id: String) {
        change { $0.remove(id) }
    }

    func setRating(_ stars: Int?, of id: String) {
        change { $0.setRating(stars, of: id) }
    }

    func setNote(_ text: String, of id: String) {
        change { $0.setNote(text, of: id) }
    }

    func setGaveUp(_ gaveUp: Bool, of id: String) {
        change { $0.setGaveUp(gaveUp, of: id) }
    }

    func setCover(_ address: String, of id: String) {
        change { $0.setCover(address, of: id) }
    }

    func addUpNext(_ id: String) {
        change { $0.addUpNext(id) }
    }

    func removeUpNext(_ id: String) {
        change { $0.removeUpNext(id) }
    }

    func setUpNext(_ ids: [String]) {
        change { $0.setUpNext(ids) }
    }

    func setLanguage(_ code: String?, of id: String) {
        change { $0.setLanguage(code, of: id) }
    }

    func setFinishedDay(_ day: Date, of id: String) {
        change { $0.setFinishedDay(day, of: id) }
    }

    func setSeriesTotal(_ total: Int?, for name: String) {
        change { $0.setSeriesTotal(total, for: name) }
    }

    // MARK: Version 0.6

    func setTags(_ tags: [String], of id: String) { change { $0.setTags(tags, of: id) } }

    @discardableResult
    func keepFilter(_ filter: BookFilter, name: String) -> SavedFilter? {
        var kept: SavedFilter?
        change { kept = $0.keepFilter(filter, name: name) }
        return kept
    }

    func changeKeptFilter(_ id: String, name: String? = nil, filter: BookFilter? = nil) {
        change { $0.changeKeptFilter(id, name: name, filter: filter) }
    }

    func removeKeptFilter(_ id: String) { change { $0.removeKeptFilter(id) } }

    func setShelves(order: [String], hidden: [String]) { change { $0.setShelves(order: order, hidden: hidden) } }

    func correct(_ id: String, title: String, author: String, series: String?, number: Double?) {
        change { $0.correct(id, title: title, author: author, series: series, number: number) }
    }

    func uncorrect(_ id: String) { change { $0.uncorrect(id) } }

    @discardableResult
    func wishSeriesPart(series: String, number: Int, title: String?) -> Book? {
        var book: Book?
        change { book = $0.wishSeriesPart(series: series, number: number, title: title) }
        return book
    }

    @discardableResult
    func addNote(bookID: String, text: String, kind: String, page: String?) -> ReadingNote? {
        var note: ReadingNote?
        change { note = $0.addNote(bookID: bookID, text: text, kind: kind, page: page) }
        return note
    }

    func changeNote(_ id: String, text: String, kind: String, page: String?, bookID: String? = nil) {
        change { $0.changeNote(id, text: text, kind: kind, page: page, bookID: bookID) }
    }

    func removeNote(_ id: String) { change { $0.removeNote(id) } }

    @discardableResult
    func addKind(_ name: String) -> NoteKind? {
        var kind: NoteKind?
        change { kind = $0.addKind(name) }
        return kind
    }

    func renameKind(_ id: String, to name: String) { change { $0.renameKind(id, to: name) } }

    func removeKind(_ id: String) { change { $0.removeKind(id) } }

    /// A book picked by chance among the ones not started; another one each time.
    func surprise() -> Book? {
        let book = data.surprise(not: lastSurprise)
        lastSurprise = book?.id
        return book
    }

    /// Asks the catalogues what a book is about, once, and remembers the answer (or that there was none).
    func lookUpAbout(_ book: Book) {
        guard !sample, !readOnly, data.shouldAskAbout(book), !askingAbout.contains(book.id) else { return }
        askingAbout.insert(book.id)
        Task {
            let answer = await AboutLookup.find(title: book.title, author: book.author)
            askingAbout.remove(book.id)
            switch answer {
            case .found(let text): change { $0.setAbout(text, of: book.id) }
            case .unknown: change { $0.setAbout(nil, of: book.id) }
            case .unreachable: break          // not an answer: ask again another time
            }
        }
    }

    func setGoal(_ count: Int?, year: Int) {
        change { $0.setGoal(count, year: year) }
    }
}

/// Starting other apps, the same way on Mac, iPhone and iPad.
enum Opener {
    static func open(_ url: URL, done: @escaping @MainActor (Bool) -> Void) {
        #if os(macOS)
        let worked = NSWorkspace.shared.open(url)
        Task { @MainActor in done(worked) }
        #else
        UIApplication.shared.open(url) { worked in
            Task { @MainActor in done(worked) }
        }
        #endif
    }

    #if os(macOS)
    static func openApp(bundle: String, files: [URL] = [], done: @escaping @MainActor (Bool) -> Void) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            Task { @MainActor in done(false) }
            return
        }
        NSWorkspace.shared.open(files, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { running, _ in
            Task { @MainActor in done(running != nil) }
        }
    }
    #endif
}

extension ReadingModel {
    /// Starts the store's own app, at the book where the store allows that.
    func open(_ copy: BookCopy, of book: Book) {
        trouble = nil
        notice = nil
        let lookFor = "Open \(copy.store == .own ? "Apple Books" : copy.store.name) and look for “\(book.title)”."
        switch copy.store {
        case .apple, .own:
            guard copy.source == .apple, let url = URL(string: "ibooks://assetid/\(copy.storeID)") else {
                trouble = "This file was added by hand, so there is nothing to open."
                return
            }
            Opener.open(url) { worked in
                if !worked { self.trouble = "Apple Books did not open. " + lookFor }
            }
        case .kindle:
            let number = copy.storeID
            let isNumber = number.count == 10 && number.allSatisfy { $0.isLetter || $0.isNumber }
            let address = isNumber ? "kindle://book?action=open&asin=\(number)" : "kindle://"
            guard let url = URL(string: address) else { return }
            Opener.open(url) { worked in
                if !worked { self.trouble = "The Kindle app did not open. " + lookFor }
            }
        case .kobo:
            #if os(macOS)
            Opener.openApp(bundle: "com.kobo.desktop.Kobo") { worked in
                if worked {
                    self.notice = "Kobo is open. Look for “\(book.title)” there."
                } else {
                    self.trouble = "Kobo's Mac app did not open. " + lookFor
                }
            }
            #else
            guard let url = URL(string: "kobo://") else { return }
            Opener.open(url) { worked in
                if worked {
                    self.notice = "Kobo is open. Look for “\(book.title)” there."
                } else {
                    self.trouble = "The Kobo app did not open. " + lookFor
                }
            }
            #endif
        }
    }

    /// Sends a lock-free book's file to a reader. On the Mac only: the files are there.
    func send(_ book: Book, to target: SendTarget) {
        trouble = nil
        notice = nil
        #if os(macOS)
        guard let copy = book.copies.first(where: { $0.lockFree && $0.filePath != nil }), let path = copy.filePath else {
            trouble = "This book has no file on this Mac to send."
            return
        }
        let file = URL(fileURLWithPath: path)
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder) else {
            trouble = "“\(file.lastPathComponent)” is not on this Mac right now. Open it once in Apple Books so it downloads, then try again."
            return
        }
        if target != .apple, isFolder.boolValue {
            // Apple Books keeps this book as an opened-up folder: pack it into one .epub file first, off the main
            // thread (a book with many pictures takes a moment). The folder is only read.
            let folder = file
            notice = "Packing “\(folder.lastPathComponent)” into one file…"
            Task {
                let packed = await Task.detached(priority: .userInitiated) { () -> URL? in
                    let out = FileManager.default.temporaryDirectory
                        .appendingPathComponent("send-\(UUID().uuidString)", isDirectory: true)
                        .appendingPathComponent(folder.lastPathComponent)
                    do {
                        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try EPUBPacker.pack(folder: folder, to: out)
                        return out
                    } catch {
                        return nil
                    }
                }.value
                self.notice = nil
                guard let packed else {
                    self.trouble = "“\(folder.lastPathComponent)” could not be packed into one file for another reader."
                    return
                }
                self.deliver(packed, of: book, copy: copy, to: target)
                // The reader has its own copy now: the packed one can go.
                try? FileManager.default.removeItem(at: packed.deletingLastPathComponent())
            }
            return
        }
        deliver(file, of: book, copy: copy, to: target)
        #else
        trouble = "Sending is done on the Mac."
        #endif
    }

    #if os(macOS)
    private func deliver(_ file: URL, of book: Book, copy: BookCopy, to target: SendTarget) {
        switch target {
        case .apple:
            if copy.source == .apple {
                notice = "This book is already in Apple Books."
                return
            }
            Opener.openApp(bundle: "com.apple.iBooksX", files: [file]) { worked in
                if worked { self.notice = "Opened in Apple Books." } else { self.trouble = "Apple Books did not open the file." }
            }
        case .kobo:
            let folder = Collector.home.appendingPathComponent("Library/CloudStorage/Dropbox/Apps/Rakuten Kobo", isDirectory: true)
            guard FileManager.default.fileExists(atPath: folder.path) else {
                trouble = "Your Kobo is not linked to Dropbox yet. On the Kobo: More › Dropbox, link it once, then send again."
                return
            }
            if place(file, in: folder) {
                notice = "Sent. Sync the Kobo and “\(book.title)” appears under My Dropbox."
            } else {
                trouble = "The file could not be put into the Kobo's Dropbox folder."
            }
        case .kindle:
            let downloads = Collector.home.appendingPathComponent("Downloads", isDirectory: true)
            guard place(file, in: downloads), let page = URL(string: "https://www.amazon.com/sendtokindle") else {
                trouble = "The file could not be copied to Downloads."
                return
            }
            Opener.open(page) { _ in }
            notice = "A copy named “\(file.lastPathComponent)” is in Downloads. On the page that opened, choose that file."
        }
    }
    #endif

    #if os(macOS)
    private func place(_ file: URL, in folder: URL) -> Bool {
        let target = folder.appendingPathComponent(file.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) { return true }
        return (try? FileManager.default.copyItem(at: file, to: target)) != nil
    }
    #endif
}
