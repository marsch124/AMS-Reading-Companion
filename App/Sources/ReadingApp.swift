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
            .onAppear { covers.off = model.sample }
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
    /// The Mac only: what the last read of each store's list said when it gave no books.
    @Published var storeTrouble: [String: String] = [:]
    @Published var readingLists = false
    @Published var cloudOn = true
    /// A line in Settings after a Kindle list file was taken in.
    @Published var fileNote: String?
    /// For pictures and screen tests: `-show <book id>` starts on that book's page.
    @Published var startBook: String?

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
        if let i = args.firstIndex(of: "-show"), i + 1 < args.count { startBook = args[i + 1] }
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
                if self.isMac, Date().timeIntervalSince(self.lastRead) > 60 { self.readLists() }
            }
        }
    }

    private func change(_ edit: (inout LibraryData) -> Void) {
        guard !readOnly else { return }
        let before = data
        edit(&data)
        guard data != before, !sample else { return }
        unsaved = true
        saveTask?.cancel()
        saveTask = Task { [store] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let snapshot = self.data
            self.unsaved = false
            let written = await Task.detached { store.save(snapshot) }.value
            self.data = LibraryData.merged(self.data, written)
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
        guard let bytes = try? Data(contentsOf: url) else {
            fileNote = "That file could not be read."
            return
        }
        let books = KindleListFile.parse(bytes)
        guard !books.isEmpty else {
            fileNote = "No books found in that file. It needs a title, an author and Amazon's book number per book."
            return
        }
        var summary = ImportSummary()
        change { data in
            summary = data.take(books, source: .kindle, complete: false)
            let shown = data.owned.filter { $0.copies.contains { $0.store == .kindle } }.count
            data.imports["kindle"] = ImportNote(date: Date(), count: shown)
        }
        fileNote = "\(books.count) Kindle books in the file: \(summary.added) new on the shelf, \(books.count - summary.added) were already there."
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
