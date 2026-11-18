import Foundation

extension LibraryData {
    /// A made-up shelf for pictures, previews and tests: invented titles and authors only, fixed dates,
    /// no cover pictures (the app draws a title tile). Every kind of shelf has something on it.
    public static var sample: LibraryData {
        // Fixed day numbers counted from 1 Jan 2026, so a picture is the same every time.
        func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + n * 86_400) }
        func copy(_ store: BookStore, _ id: String, kind: BookKind = .ebook, lockFree: Bool = false,
                  file: String? = nil, bought: Int, source: CopySource) -> BookCopy {
            BookCopy(store: store, storeID: id, kind: kind, lockFree: lockFree, filePath: file,
                     purchased: day(Double(bought)), source: source)
        }
        func book(_ title: String, _ author: String, _ copies: [BookCopy], status: ReadStatus = .unread,
                  series: String? = nil, number: Double? = nil, progress: Double? = nil, opened: Int? = nil,
                  rating: Int? = nil, note: String? = nil, gaveUp: Bool = false) -> Book {
            let added = copies.compactMap(\.purchased).min() ?? day(0)
            return Book(id: copies[0].id, title: title, author: author, series: series, seriesNumber: number,
                        copies: copies, status: status, progress: progress, lastOpened: opened.map { day(Double($0)) },
                        added: added, changed: added, rating: rating, note: note, gaveUp: gaveUp)
        }
        func wish(_ title: String, _ author: String, _ n: Int) -> Book {
            Book(id: "wish:sample-\(n)", title: title, author: author, wish: true, added: day(Double(300 + n)), changed: day(Double(300 + n)))
        }

        let lantern = "The Lantern Cycle"
        let harrow = "Harrow Station"
        let books: [Book] = [
            // Being read
            book("Salt and Signal", "Mira Valdane", [copy(.kobo, "k-salt", bought: 210, source: .kobo)],
                 status: .reading, progress: 0.42, opened: 310),
            book("A Map of Small Hours", "Joren Ashcombe", [copy(.kindle, "B0SAMPLE01", bought: 190, source: .kindle)],
                 status: .reading, progress: 0.15, opened: 305),
            // Started, then left alone for months (set aside), and one given up
            book("The Quiet Orchard Year", "Berit Salmon", [copy(.kobo, "k-orchard", bought: 150, source: .kobo)],
                 status: .reading, progress: 0.3, opened: 100),
            book("Letters from Low Tide", "Odell Marchetti", [copy(.kindle, "B0SAMPLE03", bought: 170, source: .kindle)],
                 status: .reading, progress: 0.55, opened: 60),
            book("The Copper Almanac", "Vesna Hallgren", [copy(.kobo, "k-almanac", bought: 140, source: .kobo)],
                 status: .reading, progress: 0.12, opened: 90, gaveUp: true),
            // Unread, a series with a gap (books 1, 2 and 4)
            book("Ember Road", "Teodor Wrenfield", [copy(.kobo, "k-ember", bought: 250, source: .kobo)],
                 series: lantern, number: 1),
            book("Ash Harbour", "Teodor Wrenfield", [copy(.kobo, "k-ash", bought: 262, source: .kobo)],
                 series: lantern, number: 2),
            book("Glass Tide", "Teodor Wrenfield", [copy(.kobo, "k-glass", bought: 290, source: .kobo)],
                 series: lantern, number: 4),
            // A second series of two
            // (book 1 is finished and book 2 not started: "What next?" offers book 2 first)
            book("Harrow Station", "Ilse Quennell", [copy(.apple, "a-harrow1", bought: 240, source: .apple)],
                 status: .finished, series: harrow, number: 1, opened: 250),
            book("Beyond Harrow", "Ilse Quennell", [copy(.apple, "a-harrow2", bought: 270, source: .apple)],
                 series: harrow, number: 2),
            // One book owned twice: Kobo and Kindle, both ebooks
            book("Brass Meridian", "Corin Faulkes", [copy(.kobo, "k-brass", bought: 280, source: .kobo),
                                                     copy(.kindle, "B0SAMPLE02", bought: 285, source: .kindle)]),
            // An ebook in Kobo and its audiobook in Apple Books (not "twice")
            book("Winter Lighthouse", "Saskia Brandt", [copy(.kobo, "k-winter", bought: 295, source: .kobo),
                                                        copy(.apple, "a-winter-audio", kind: .audiobook, bought: 296, source: .apple)]),
            // Own files, lock-free
            book("Recipes for a Slow Week", "Hedda Lindqvist",
                 [copy(.own, "file-recipes", lockFree: true, file: "/Sample/Recipes for a Slow Week.epub", bought: 300, source: .file)]),
            book("Field Notes on Tidewater Birds", "Anselm Rook",
                 [copy(.own, "file-birds", kind: .pdf, lockFree: true, file: "/Sample/Field Notes on Tidewater Birds.pdf", bought: 120, source: .file)],
                 status: .finished, opened: 140, rating: 5,
                 note: "Read it on the ferry. The tern chapter is the best."),
            book("A Short Manual of Knots", "Petra Oyelaran",
                 [copy(.own, "file-knots", kind: .pdf, lockFree: true, file: "/Sample/A Short Manual of Knots.pdf", bought: 100, source: .file)],
                 status: .finished, opened: 130),
            // Audiobooks
            book("Night Ferry to Sundmark", "Lowen Takeda", [copy(.apple, "a-ferry-audio", kind: .audiobook, bought: 150, source: .apple)],
                 status: .finished, opened: 200),
            book("The Whispering Dunes", "Maren Oduya", [copy(.apple, "a-dunes-audio", kind: .audiobook, bought: 160, source: .apple)],
                 status: .finished, opened: 220, rating: 4, note: "Slow start, worth it."),
            // Wishes
            wish("The Clockmaker's Weather", "Yara Pellegrin", 1),
            wish("Lanterns Under Ice", "Teodor Wrenfield", 2),
            wish("A Garden of Borrowed Rooms", "Nils Everhart", 3),
        ]
        let imports: [String: ImportNote] = [
            "apple": ImportNote(date: day(310), count: 5),
            "kobo": ImportNote(date: day(310), count: 7),
            "kindle": ImportNote(date: day(305), count: 3),
        ]
        var data = LibraryData(books: books, imports: imports)
        // What a catalogue said about the Lantern Cycle: five books, all named.
        data.setSeries(SeriesInfo(total: 5, volumes: [
            SeriesVolume(number: 1, title: "Ember Road"),
            SeriesVolume(number: 2, title: "Ash Harbour"),
            SeriesVolume(number: 3, title: "The Salt Lamp"),
            SeriesVolume(number: 4, title: "Glass Tide"),
            SeriesVolume(number: 5, title: "Lantern Rising"),
        ], checked: day(310)), for: lantern)
        // The owner's own Up next list, a goal for the year, and a language for each book.
        data.upNext = ["apple:a-harrow2", "kobo:k-brass"]
        data.upNextChanged = day(310)
        data.goals = ["2026": 12]
        data.goalsChanged = day(1)
        data.guessLanguages()

        // Version 0.6: tags, reading notes, a kept filter, what a book is about, and what the stores' lists changed.
        data.setTags(["sea", "slow read"], of: "kobo:k-salt", now: day(300))
        data.setTags(["sea"], of: "kobo:k-winter", now: day(300))
        data.setTags(["series", "slow read"], of: "kobo:k-ember", now: day(300))
        data.setTags(["cooking"], of: "own:file-recipes", now: day(300))
        data.setAbout("A lighthouse keeper's daughter finds an old signal book in the salt store and starts to answer "
                      + "messages nobody has sent for forty years. A quiet novel about the sea, patience and the "
                      + "people who wait on shore.", of: "kobo:k-salt")
        data.addNote(bookID: "kobo:k-salt", text: "The sea keeps what it is given, and gives back only stories.",
                     kind: "quote", page: "41", now: day(308), newID: "n1")
        data.addNote(bookID: "kobo:k-salt", text: "The harbour master knows more than he says.", kind: "thought", now: day(309), newID: "n2")
        data.addNote(bookID: "kobo:k-salt", text: "fathom", kind: "word", page: "57", now: day(309.5), newID: "n3")
        data.addNote(bookID: "kobo:k-salt", text: "Look up the old map of the bay.", kind: "todo", now: day(310), newID: "n4")
        data.addNote(bookID: "kindle:B0SAMPLE01", text: "Nobody is lost who still counts the hours.", kind: "quote",
                     page: "12", now: day(304), newID: "n5")
        data.addNote(bookID: "kindle:B0SAMPLE01", text: "Reminds me of the night trains to the north.", kind: "thought", now: day(305), newID: "n6")
        data.addNote(bookID: "apple:a-harrow1", text: "Read part two before spring.", kind: "todo", now: day(251), newID: "n7")
        var kobo = BookFilter()
        kobo.stores = [.kobo]
        kobo.states = [.unread]
        data.keepFilter(kobo, name: "Kobo, not read", now: day(300), newID: "sample-kobo")
        data.changes = [
            ChangeEntry(date: day(310), store: "kobo", came: ["Glass Tide"], left: []),
            ChangeEntry(date: day(296), store: "apple", came: ["Winter Lighthouse"], left: ["A Year of Borrowed Light"]),
        ]
        // Version 0.8: a store's collection on a copy, a To do that is done, a manual put away, a book that has
        // waited since 2024, and one that came a few days ago (the only date here that moves with today).
        if let i = data.books.firstIndex(where: { $0.id == "kobo:k-salt" }) { data.books[i].copies[0].collections = ["Book club"] }
        if let i = data.books.firstIndex(where: { $0.id == "kobo:k-glass" }) { data.books[i].copies[0].collections = ["Book club"] }
        data.setDone(true, note: "n7", now: day(260))
        data.books.append(Book(id: "kobo:k-manual", title: "Reader Handbook", author: "Kestrel Devices",
                               copies: [BookCopy(store: .kobo, storeID: "k-manual", purchased: day(20), source: .kobo)],
                               added: day(20), changed: day(20)))
        data.setPutAway(true, of: ["kobo:k-manual"], now: day(21))
        data.books.append(Book(id: "kindle:B0SAMPLE09", title: "The Long Shore Walk", author: "Odell Marchetti",
                               copies: [BookCopy(store: .kindle, storeID: "B0SAMPLE09", purchased: day(-500), source: .kindle)],
                               added: day(-500), changed: day(-500), language: "en"))
        let lately = Date().addingTimeInterval(-4 * 86_400)
        data.books.append(Book(id: "apple:a-new", title: "Tide Tables for Beginners", author: "Mira Valdane",
                               copies: [BookCopy(store: .apple, storeID: "a-new", purchased: lately, source: .apple)],
                               added: lately, changed: lately, language: "en"))
        return data
    }
}
