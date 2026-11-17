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
    private var cloudAsked = false

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
            let cloud = readCloud()
            switch (local, cloud) {
            case let (l?, c?): return LibraryData.merged(c, l)
            case let (l?, nil): return l
            case let (nil, c?): return c
            default: return nil
            }
        }
    }

    /// Writes the shelf, joined with what the file holds now. Gives back what was written.
    func save(_ mine: LibraryData) -> LibraryData {
        queue.sync {
            guard !mine.books.isEmpty, !mine.isNewer else { return mine }
            var out = mine
            if let disk = readCloud() {
                out = LibraryData.merged(disk, mine)
                if disk.isNewer { return out }
            }
            guard let bytes = try? out.encoded() else { return mine }
            try? bytes.write(to: localFile, options: .atomic)
            if let file = cloudFile() {
                var problem: NSError?
                NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
                    try? bytes.write(to: url, options: .atomic)
                }
            }
            safetyCopy(bytes)
            return out
        }
    }

    // MARK: iCloud

    private func cloudFile() -> URL? {
        if !cloudAsked {
            cloudAsked = true
            if let root = FileManager.default.url(forUbiquityContainerIdentifier: Self.container) {
                let documents = root.appendingPathComponent("Documents", isDirectory: true)
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                cloudFolder = documents
            }
        }
        return cloudFolder?.appendingPathComponent("library.json")
    }

    private func readCloud() -> LibraryData? {
        guard let file = cloudFile() else { return nil }
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
        var result: LibraryData?
        var problem: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in
            if let data = try? Data(contentsOf: url) { result = try? LibraryData.decode(data) }
        }
        // What iCloud parked when two devices wrote at the same moment: join it in, then clear it away.
        if let parked = NSFileVersion.unresolvedConflictVersionsOfItem(at: file), !parked.isEmpty {
            for version in parked {
                if let data = try? Data(contentsOf: version.url), let other = try? LibraryData.decode(data) {
                    result = result.map { LibraryData.merged($0, other) } ?? other
                }
                version.isResolved = true
            }
            try? NSFileVersion.removeOtherVersionsOfItem(at: file)
        }
        return result
    }

    // MARK: Safety copies

    private func safetyCopy(_ bytes: Data) {
        let safety = folder.appendingPathComponent("Safety", isDirectory: true)
        try? FileManager.default.createDirectory(at: safety, withIntermediateDirectories: true)
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")
        let today = safety.appendingPathComponent("library-\(day.string(from: Date())).json")
        guard !FileManager.default.fileExists(atPath: today.path) else { return }
        try? bytes.write(to: today, options: .atomic)
        let all = ((try? FileManager.default.contentsOfDirectory(atPath: safety.path)) ?? [])
            .filter { $0.hasPrefix("library-") }.sorted()
        for old in all.dropLast(14) {
            try? FileManager.default.removeItem(at: safety.appendingPathComponent(old))
        }
    }
}
