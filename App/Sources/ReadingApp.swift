import ReadingCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
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
    }
}

enum SendTarget: String { case apple, kobo, kindle }

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
    /// The Mac only: what the last read of each store's list said when it gave no books.
    @Published var storeTrouble: [String: String] = [:]
    @Published var readingLists = false
    @Published var cloudOn = true
    /// A line in Settings after a Kindle list file was taken in.
    @Published var fileNote: String?
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
        if let i = args.firstIndex(of: "-shelf"), i + 1 < args.count { startShelf = args[i + 1] }
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

    private func change(_ edit: (inout LibraryData) -> Void) {
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

    // MARK: The Share check (iPhone and iPad)

    /// Gives the Share extension a small list of the shelf, and takes in the wishes made from it.
    private func shareShelf() {
        #if os(iOS)
        guard !sample else { return }
        let entries = data.shown.map { ShelfEntry(title: $0.title, author: $0.author, stores: $0.stores.map(\.name), wish: $0.wish) }
        Task.detached(priority: .utility) { ShareFiles.writeIndex(entries) }
        #endif
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
            data.take(read.books, source: source, complete: complete)
            // Kindle's Mac list is only its latest sync, so its count is "books on the shelf", not "books in the list".
            let shown = source == .kindle
                ? data.owned.filter { $0.copies.contains { $0.store == .kindle } }.count
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
            let shown = data.owned.filter { $0.copies.contains { $0.store == .kindle } }.count
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
            trouble = "Apple Books keeps “\(file.lastPathComponent)” as an opened-up folder, which other readers cannot take yet. PDFs and single-file books can be sent."
            return
        }
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
        #else
        trouble = "Sending is done on the Mac."
        #endif
    }

    #if os(macOS)
    private func place(_ file: URL, in folder: URL) -> Bool {
        let target = folder.appendingPathComponent(file.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) { return true }
        return (try? FileManager.default.copyItem(at: file, to: target)) != nil
    }
    #endif
}
