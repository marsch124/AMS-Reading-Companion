import Foundation

extension LibraryData {
    /// A made-up shelf for pictures, previews and tests: invented titles and authors only, fixed dates,
    /// no cover pictures (the app draws a title tile). Every kind of shelf has something on it.
    public static var sample: LibraryData {
        // Fixed day numbers counted from 1 Jan 2026, so a picture is the same every time.
        func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + Double(n) * 86_400) }
        func copy(_ store: BookStore, _ id: String, kind: BookKind = .ebook, lockFree: Bool = false,
                  file: String? = nil, bought: Int, source: CopySource) -> BookCopy {
            BookCopy(store: store, storeID: id, kind: kind, lockFree: lockFree, filePath: file,
                     purchased: day(bought), source: source)
        }
        func book(_ title: String, _ author: String, _ copies: [BookCopy], status: ReadStatus = .unread,
                  series: String? = nil, number: Double? = nil, progress: Double? = nil, opened: Int? = nil,
                  rating: Int? = nil, note: String? = nil, gaveUp: Bool = false) -> Book {
            let added = copies.compactMap(\.purchased).min() ?? day(0)
            return Book(id: copies[0].id, title: title, author: author, series: series, seriesNumber: number,
                        copies: copies, status: status, progress: progress, lastOpened: opened.map(day),
                        added: added, changed: added, rating: rating, note: note, gaveUp: gaveUp)
        }
        func wish(_ title: String, _ author: String, _ n: Int) -> Book {
            Book(id: "wish:sample-\(n)", title: title, author: author, wish: true, added: day(300 + n), changed: day(300 + n))
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
        return data
    }
}
