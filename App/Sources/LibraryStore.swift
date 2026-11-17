import Foundation
import ReadingCore

/// Where the shelf is kept: one file, `library.json`, in the app's iCloud Drive folder, so Mac, iPhone and iPad
/// share it. A copy on the device itself opens at once and still works without iCloud.
///
/// The rules that keep the shelf safe:
/// - before writing, what is in the file is read and joined in (per book the newer change wins);
/// - a version iCloud parked because two devices wrote at once is joined in, never dropped;
/// - an empty shelf is never written over a file;
/// - a file from a newer version of the app is never written over;
/// - once a day a safety copy is kept on the device, 14 days back.
final class LibraryStore: @unchecked Sendable {
    static let container = "iCloud.com.schabbauer.AMSReadingCompanion"

    private let queue = DispatchQueue(label: "com.schabbauer.AMSReadingCompanion.store")
    private var cloudFolder: URL?
    private var cloudAsked = Date.distantPast

    private enum CloudRead {
        /// No iCloud here, or no file there yet.
        case absent
        /// The file is there but could not be read: never write over it.
        case unreadable
        /// The file, with `joined` true when a version iCloud had parked was joined in.
        case got(LibraryData, joined: Bool)
    }

    private var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("AMSReadingCompanion", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var localFile: URL { folder.appendingPathComponent("library.json") }

    /// The copy on this device: quick, for the first picture on screen.
    func loadLocal() -> LibraryData? {
        guard let data = try? Data(contentsOf: localFile) else { return nil }
        return try? LibraryData.decode(data)
    }

    /// Whether the iCloud folder is there (signed in to iCloud, iCloud Drive on).
    var cloudOn: Bool { queue.sync { cloudFile() != nil } }

    /// The device's copy and iCloud's file made into one. Slow the first time: call it off the main thread.
    func load() -> LibraryData? {
        queue.sync {
            let local = loadLocal()
            guard case let .got(cloud, joined) = readCloud() else { return local }
            let out = local.map { LibraryData.merged(cloud, $0) } ?? cloud
            // A parked version was joined in and cleared away: write the joined shelf back at once,
            // so what it held is not only in memory.
            if joined, !out.isNewer, !out.books.isEmpty, let bytes = try? out.encoded() {
                write(bytes, cloud: true)
            }
            return out
        }
    }

    /// Writes the shelf, joined with what the file holds now. Gives back what was written.
    func save(_ mine: LibraryData) -> LibraryData {
        queue.sync {
            guard !mine.books.isEmpty, !mine.isNewer else { return mine }
            var out = mine
            var cloud = true
            switch readCloud() {
            case .absent:
                break
            case .unreadable:
                cloud = false
            case let .got(disk, _):
                out = LibraryData.merged(disk, mine)
                if disk.isNewer { return out }
            }
            guard let bytes = try? out.encoded() else { return mine }
            write(bytes, cloud: cloud)
            return out
        }
    }

    private func write(_ bytes: Data, cloud: Bool) {
        safetyCopy(fallback: bytes)
        try? bytes.write(to: localFile, options: .atomic)
        guard cloud, let file = cloudFile() else { return }
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            try? bytes.write(to: url, options: .atomic)
        }
    }

    // MARK: iCloud

    private func cloudFile() -> URL? {
        // Asked again now and then, so signing in to iCloud later is noticed without restarting the app.
        if cloudFolder == nil, Date().timeIntervalSince(cloudAsked) > 30 {
            cloudAsked = Date()
            if let root = FileManager.default.url(forUbiquityContainerIdentifier: Self.container) {
                let documents = root.appendingPathComponent("Documents", isDirectory: true)
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                cloudFolder = documents
            }
        }
        return cloudFolder?.appendingPathComponent("library.json")
    }

    private func readCloud() -> CloudRead {
        guard let file = cloudFile() else { return .absent }
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
        var result: LibraryData?
        var there = false
        var joined = false
        var problem: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in
            there = FileManager.default.fileExists(atPath: url.path)
            if let data = try? Data(contentsOf: url) { result = try? LibraryData.decode(data) }
        }
        // iCloud may know the file before it has arrived on this device.
        if !there, (try? file.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true { there = true }
        // What iCloud parked when two devices wrote at the same moment: join it in, then clear it away.
        if let parked = NSFileVersion.unresolvedConflictVersionsOfItem(at: file), !parked.isEmpty {
            for version in parked {
                if let data = try? Data(contentsOf: version.url), let other = try? LibraryData.decode(data) {
                    result = result.map { LibraryData.merged($0, other) } ?? other
                    joined = true
                }
                version.isResolved = true
            }
            try? NSFileVersion.removeOtherVersionsOfItem(at: file)
        }
        if let result { return .got(result, joined: joined) }
        return there ? .unreadable : .absent
    }

    // MARK: Safety copies

    /// Once a day, BEFORE the first write of the day: the shelf as it was. On the very first day, the new shelf.
    private func safetyCopy(fallback bytes: Data) {
        let safety = folder.appendingPathComponent("Safety", isDirectory: true)
        try? FileManager.default.createDirectory(at: safety, withIntermediateDirectories: true)
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")
        let today = safety.appendingPathComponent("library-\(day.string(from: Date())).json")
        guard !FileManager.default.fileExists(atPath: today.path) else { return }
        let before = (try? Data(contentsOf: localFile)) ?? bytes
        try? before.write(to: today, options: .atomic)
        let all = ((try? FileManager.default.contentsOfDirectory(atPath: safety.path)) ?? [])
            .filter { $0.hasPrefix("library-") }.sorted()
        for old in all.dropLast(14) {
            try? FileManager.default.removeItem(at: safety.appendingPathComponent(old))
        }
    }
}
