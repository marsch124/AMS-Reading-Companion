import Foundation

// The rules that came with version 0.5: the Up next list, a book's language and finishing day,
// a series total typed by hand, the year in books, the numbers page and the shelf as a list.

/// One year of finished books.
public struct ReadingYear: Identifiable, Equatable, Sendable {
    public var year: Int
    /// Finished in that year, the latest first.
    public var books: [Book]
    /// How many books the owner set out to finish that year. nil = no goal.
    public var goal: Int?
    public var id: Int { year }
}

/// One line of the numbers page: a name and how many.
public struct NumberLine: Identifiable, Equatable, Sendable {
    public var name: String
    public var count: Int
    /// The colour name for its bar (see the app's Theme), or a store's raw name for a store's own colour.
    public var colour: String
    public var id: String { name }
    public init(name: String, count: Int, colour: String) { self.name = name; self.count = count; self.colour = colour }
}

/// The shelf counted.
public struct ShelfNumbers: Equatable, Sendable {
    public var owned = 0
    public var wishes = 0
    public var lockFree = 0
    public var boughtTwice = 0
    /// Per store, the biggest first. A book held in two stores counts in both.
    public var stores: [NumberLine] = []
    /// Ebooks, audiobooks, PDFs. A book held both ways counts in both.
    public var kinds: [NumberLine] = []
    /// Not read yet, reading, set aside or given up, finished.
    public var reading: [NumberLine] = []
    /// Per language, the biggest first; "Not known" last.
    public var languages: [NumberLine] = []
    /// Books bought per year, the latest year first.
    public var boughtByYear: [NumberLine] = []
    /// Books finished per year, the latest year first.
    public var finishedByYear: [NumberLine] = []
    public var rated = 0
    /// The mean of the owner's stars, nil when nothing is rated.
    public var meanStars: Double?
}

extension LibraryData {

    // MARK: Up next

    /// The Up next list as books, in the owner's order: only books on the shelf that are not started yet.
    public var upNextBooks: [Book] {
        var seen = Set<String>()
        return upNext.compactMap { id in
            guard seen.insert(id).inserted, let book = book(id), !book.copies.isEmpty, !book.putAway, book.status == .unread else { return nil }
            return book
        }
    }

    public func isUpNext(_ id: String) -> Bool { upNextBooks.contains { $0.id == id } }

    /// Only a book on the shelf that is not started can stand on the list.
    public func canBeUpNext(_ book: Book) -> Bool { !book.copies.isEmpty && !book.removed && !book.putAway && book.status == .unread }

    /// Puts a book at the end of the Up next list. Nothing happens for a book that cannot stand there or already does.
    public mutating func addUpNext(_ id: String, now: Date = Date()) {
        guard let book = book(id), canBeUpNext(book), !isUpNext(id) else { return }
        upNext = upNextBooks.map(\.id) + [id]
        upNextChanged = now.wholeSeconds
    }

    public mutating func removeUpNext(_ id: String, now: Date = Date()) {
        guard upNext.contains(id) else { return }
        upNext = upNextBooks.map(\.id).filter { $0 != id }
        upNextChanged = now.wholeSeconds
    }

    /// The whole list in a new order (after the owner moved or took out books). Ids that cannot stand there are dropped.
    public mutating func setUpNext(_ ids: [String], now: Date = Date()) {
        var seen = Set<String>()
        let clean = ids.filter { id in
            guard seen.insert(id).inserted, let book = book(id) else { return false }
            return canBeUpNext(book)
        }
        guard clean != upNext else { return }
        upNext = clean
        upNextChanged = now.wholeSeconds
    }

    // MARK: Language

    public mutating func setLanguage(_ code: String?, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].language = BookLanguage.code(code)
        books[i].languageByHand = true
        books[i].changed = now.wholeSeconds
    }

    /// The languages among these books, the most books first, with how many each.
    public static func languages(in books: [Book]) -> [(code: String, count: Int)] {
        var counts: [String: Int] = [:]
        for book in books { if let code = book.language { counts[code, default: 0] += 1 } }
        return counts.map { (code: $0.key, count: $0.value) }.sorted { ($1.count, $0.code) < ($0.count, $1.code) }
    }

    /// Fills in a guessed language for every book that has none. Not the owner's doing: `changed` stays.
    public mutating func guessLanguages() {
        for i in books.indices where books[i].language == nil && !books[i].languageByHand {
            books[i].language = BookLanguage.guess(title: books[i].title)
        }
    }

    /// The quiet housekeeping after the stores' lists were read. Nothing here is the owner's doing, so no book's
    /// `changed` moves: a guessed language for books without one; a fixed finishing day for books finished before
    /// the day was kept (else opening such a book again would move it to another year); and the Up next list
    /// without the books a store has meanwhile seen started.
    public mutating func tidy(now: Date = Date()) {
        guessLanguages()
        for i in books.indices where books[i].status == .finished && books[i].finished == nil {
            books[i].finished = books[i].lastOpened
        }
        let still = upNextBooks.map(\.id)
        if still != upNext {
            upNext = still
            upNextChanged = now.wholeSeconds
        }
    }

    // MARK: Finishing day

    /// The owner corrects the day a book was finished. Only a finished book has one.
    public mutating func setFinishedDay(_ day: Date, of id: String, now: Date = Date()) {
        guard let i = books.firstIndex(where: { $0.id == id }), books[i].status == .finished else { return }
        books[i].finished = day.wholeSeconds
        books[i].changed = now.wholeSeconds
    }

    // MARK: Series total by hand

    /// The owner types how many books a series has. nil or 0 takes his number away again (a catalogue may fill it later).
    public mutating func setSeriesTotal(_ total: Int?, for name: String, now: Date = Date()) {
        let key = BookMatch.plain(name.trimmingCharacters(in: .whitespaces))
        guard !key.isEmpty else { return }
        var info = series[key] ?? SeriesInfo(total: nil)
        if let total, total >= 1 {
            info.total = min(total, 200)
            info.byHand = true
        } else {
            info.total = nil
            info.byHand = false
        }
        info.checked = now.wholeSeconds
        series[key] = info
    }

    // MARK: Year in books

    /// The goal that holds for a year: the one set for it, else the latest one set for an earlier year.
    public func goal(year: Int) -> Int? {
        if let own = goals[String(year)] { return own > 0 ? own : nil }
        let earlier = goals.compactMap { key, value -> (Int, Int)? in
            guard let y = Int(key), y < year else { return nil }
            return (y, value)
        }.max { $0.0 < $1.0 }
        guard let value = earlier?.1, value > 0 else { return nil }
        return value
    }

    /// Sets the goal from this year on. nil or 0 = no goal from this year on.
    public mutating func setGoal(_ count: Int?, year: Int, now: Date = Date()) {
        goals[String(year)] = max(0, min(count ?? 0, 999))
        goalsChanged = now.wholeSeconds
    }

    /// Every year with a finished book, the latest first, and always this year.
    public func readingYears(now: Date = Date(), calendar: Calendar = .current) -> [ReadingYear] {
        var byYear: [Int: [Book]] = [:]
        for book in owned {
            guard let day = book.finishedDay else { continue }
            byYear[calendar.component(.year, from: day), default: []].append(book)
        }
        let thisYear = calendar.component(.year, from: now)
        if byYear[thisYear] == nil { byYear[thisYear] = [] }
        return byYear.keys.sorted(by: >).map { year in
            let books = byYear[year, default: []].sorted {
                ($0.finishedDay ?? .distantPast, $1.title) > ($1.finishedDay ?? .distantPast, $0.title)
            }
            return ReadingYear(year: year, books: books, goal: goal(year: year))
        }
    }

    /// Finished books whose finishing day nobody knows.
    public var finishedWithoutDay: [Book] {
        owned.filter { $0.status == .finished && $0.finishedDay == nil }
            .sorted { BookMatch.titleKey($0.title) < BookMatch.titleKey($1.title) }
    }

    /// How a year stands against its goal on a day: "8 of 24 · 2 ahead", "… · 3 behind", "… · on track",
    /// "24 of 24 · goal reached". For a year that is over only the count against the goal.
    public static func goalLine(finished: Int, goal: Int, year: Int, now: Date = Date(), calendar: Calendar = .current) -> String {
        let start = "\(finished) of \(goal)"
        if finished >= goal { return start + " · goal reached" }
        let thisYear = calendar.component(.year, from: now)
        guard year == thisYear else { return start }
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let days = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let due = Int((Double(goal) * Double(day) / Double(days)).rounded(.down))
        if finished > due { return start + " · \(finished - due) ahead" }
        if finished < due { return start + " · \(due - finished) behind" }
        return start + " · on track"
    }

    // MARK: Numbers

    public func numbers(calendar: Calendar = .current) -> ShelfNumbers {
        var n = ShelfNumbers()
        let owned = self.owned
        n.owned = owned.count
        n.wishes = shown.filter(\.wish).count
        n.lockFree = owned.filter(\.isLockFree).count
        n.boughtTwice = owned.filter(\.ownedTwice).count

        let storeOrder: [BookStore] = [.kobo, .kindle, .apple, .own]
        n.stores = storeOrder.map { store in
            NumberLine(name: store.name, count: owned.filter { $0.copies.contains { $0.store == store } }.count, colour: store.rawValue)
        }.filter { $0.count > 0 }.sorted { $0.count > $1.count }

        let kinds: [(String, BookKind, String)] = [("Ebooks", .ebook, "purple"), ("Audiobooks", .audiobook, "amber"), ("PDFs", .pdf, "teal")]
        n.kinds = kinds.map { name, kind, colour in
            NumberLine(name: name, count: owned.filter { $0.copies.contains { $0.kind == kind } }.count, colour: colour)
        }.filter { $0.count > 0 }

        let aside = owned.filter { $0.status == .reading }.count
        let current = shelf("reading")?.books.count ?? 0
        n.reading = [
            NumberLine(name: "Not read yet", count: owned.filter { $0.status == .unread }.count, colour: "red"),
            NumberLine(name: "Reading now", count: current, colour: "purple"),
            NumberLine(name: "Set aside or gave up", count: aside - current, colour: "brown"),
            NumberLine(name: "Finished", count: owned.filter { $0.status == .finished }.count, colour: "grey"),
        ].filter { $0.count > 0 }

        n.languages = Self.languages(in: owned).map { NumberLine(name: BookLanguage.name($0.code), count: $0.count, colour: "blue") }
        let unknown = owned.filter { $0.language == nil }.count
        if unknown > 0 { n.languages.append(NumberLine(name: "Not known", count: unknown, colour: "grey")) }

        var bought: [Int: Int] = [:]
        var finished: [Int: Int] = [:]
        for book in owned {
            if let day = book.purchased { bought[calendar.component(.year, from: day), default: 0] += 1 }
            if let day = book.finishedDay { finished[calendar.component(.year, from: day), default: 0] += 1 }
        }
        n.boughtByYear = bought.keys.sorted(by: >).map { NumberLine(name: String($0), count: bought[$0] ?? 0, colour: "green") }
        n.finishedByYear = finished.keys.sorted(by: >).map { NumberLine(name: String($0), count: finished[$0] ?? 0, colour: "purple") }

        let stars = owned.compactMap(\.rating)
        n.rated = stars.count
        n.meanStars = stars.isEmpty ? nil : Double(stars.reduce(0, +)) / Double(stars.count)
        return n
    }

    // MARK: The shelf as a list

    /// The columns of the list, in order.
    public static let listColumns = ["Title", "Author", "Series", "Number", "Stores", "Kind", "Language", "Status",
                                     "Finished", "Stars", "Note", "Bought", "Lock-free"]

    /// One book as the cells of its line, in the order of `listColumns`.
    public static func listCells(_ book: Book) -> [String] {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_GB")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        let number = book.seriesNumber.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        var kinds: [String] = []
        if book.copies.contains(where: { $0.kind == .ebook }) { kinds.append("ebook") }
        if book.copies.contains(where: { $0.kind == .audiobook }) { kinds.append("audiobook") }
        if book.copies.contains(where: { $0.kind == .pdf }) { kinds.append("PDF") }
        let status: String
        if book.wish { status = "Wish" }
        else if book.gaveUp && book.status == .reading { status = "Gave up" }
        else { status = ["unread": "Not read", "reading": "Reading", "finished": "Finished"][book.status.rawValue] ?? "" }
        return [
            book.title, book.author, book.series ?? "", number,
            book.stores.map(\.name).joined(separator: ", "), kinds.joined(separator: ", "),
            book.language.map(BookLanguage.name) ?? "", status,
            book.finishedDay.map(day.string(from:)) ?? "", book.rating.map(String.init) ?? "", book.note ?? "",
            book.purchased.map(day.string(from:)) ?? "", book.isLockFree ? "yes" : "",
        ]
    }

    /// Every shown book, by title; wishes last.
    public var listBooks: [Book] {
        shown.sorted { ($0.wish ? 1 : 0, BookMatch.titleKey($0.title), $0.id) < ($1.wish ? 1 : 0, BookMatch.titleKey($1.title), $1.id) }
    }

    /// The whole shelf as a table a spreadsheet opens (comma-separated, one line per book, a heading line first).
    public func listTable() -> String {
        func cell(_ text: String) -> String {
            let plain = text.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ")
            guard plain.contains(where: { $0 == "," || $0 == "\"" || $0 == ";" }) else { return plain }
            return "\"" + plain.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let lines = [Self.listColumns] + listBooks.map(Self.listCells)
        return lines.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}
