import Foundation

/// The words of "How it works" and "What's new". Every release adds its entry at the top of `news`
/// and changes the parts of `guide` that it touched.
enum Guide {
    struct Part: Identifiable {
        let title: String
        let text: [String]
        var id: String { title }
    }

    struct Release: Identifiable {
        let version: String
        let date: String
        let items: [String]
        var id: String { version }
    }

    static let guide: [Part] = [
        Part(title: "What this app is", text: [
            "AMS Reading Companion is one shelf for every book you have in three stores: Rakuten Kobo, Apple Books and Amazon Kindle. Your own files (EPUB and PDF) stand on it too.",
            "It shows what you own and where. It stops you buying a book twice. It helps you move books that have no lock.",
            "It never takes a store's lock off a book. A locked book still opens only in its own store's app or reader.",
            "On the shelf: bought ebooks, audiobooks and your own files. Free samples are left out.",
        ]),
        Part(title: "Where the lists come from", text: [
            "The Mac collects the lists. It does so each time the app opens there, and when you press Refresh in Settings.",
            "iPhone and iPad cannot read the stores. They show the same shelf through iCloud.",
            "So after you buy a book, open the store's app on the Mac once so that it syncs. Then open AMS Reading Companion on the Mac.",
            "Settings shows for each store how many books were found and when.",
        ]),
        Part(title: "Apple Books", text: [
            "The whole list is read from the Books app on your Mac: ebooks, audiobooks and PDFs.",
            "This list is the truth. A book that leaves it leaves your shelf at the next read.",
            "If the list comes back empty (for example when you are signed out), nothing is removed.",
        ]),
        Part(title: "Kobo", text: [
            "The whole list is read from Kobo's app on your Mac. Sign in there once and let it sync.",
            "This list is the truth too. A book that leaves it leaves your shelf at the next read. An empty list removes nothing.",
            "This part has not yet been checked against your real Kobo list.",
        ]),
        Part(title: "Kindle", text: [
            "The Kindle app on the Mac keeps only a small list from its latest sync, not your whole library. Built-in dictionaries and entries without a purchase day are left out. On 17 November 2026 that left 1 book: the one you bought. So Kindle books come in three ways.",
            "One: new purchases are picked up from the Kindle app on the Mac after it has synced.",
            "Two: a one-time list of your whole Kindle library. Take it in under Settings › Import Kindle list. It can be a CSV or JSON file with title, author and Amazon's book number for each book.",
            "Three: by hand with Add a book.",
            "Kindle books are never removed by themselves, because the Mac's Kindle list is never complete. The one exception: if a store's list later marks a book on your shelf as a free sample or a built-in item, it leaves the shelf at the next read. You can also remove a book yourself on its page.",
        ]),
        Part(title: "One book, several stores", text: [
            "The same title and author in two stores is one book with two store marks.",
            "Matching ignores capital letters, accents, a subtitle after a colon and a leading “The”. “Herbert, Frank” counts as “Frank Herbert”.",
            "When you own the same kind twice (two ebooks, or two audiobooks) the book says “Owned twice”.",
            "An ebook and its audiobook are not “twice”.",
        ]),
        Part(title: "The shelves", text: [
            "The main screen is a stack of shelves. Each has a heading in its own colour and a row of covers that scrolls sideways. A book can stand on several shelves. Empty shelves are left out, except the Wish list.",
            "Reading now (purple): the books you opened lately. A book a store says you started, but that you have not opened in the 90 days before your latest reading, stands under Not read yet again. A book you set to Reading yourself always stays here.",
            "Not read yet (red): newest purchase first, with the count, for example “Not read yet · 84”.",
            "One shelf for each series of which you own two books or more (green), in series order, with a note such as “3 owned · missing 2 and 4”. Gaps are known only below the highest number you own. The app does not know how many books a series has in all.",
            "Lock-free (teal). Audiobooks (amber). Finished (grey): most recent first. Wish list (blue): always shown.",
            "Tap a shelf's heading to see all its books in a grid.",
        ]),
        Part(title: "The dots and marks", text: [
            "Under each cover stand small coloured dots for its stores: Kobo red-orange, Kindle blue, Apple Books grey, own file teal.",
            "An open-lock mark means the book has no lock. A headphones mark means an audiobook.",
            "A book without a cover picture shows a coloured tile with its title.",
        ]),
        Part(title: "Search: do I own it?", text: [
            "Tap the search button and type a title, an author or a series.",
            "Each match shows the book with its stores. Use this before you buy.",
            "If nothing matches, the app says “Not on your shelf” and offers a button to add what you typed.",
        ]),
        Part(title: "Add a book", text: [
            "Tap the add button in the toolbar. Type the title and the author, and choose where the book is: Wish list (the usual choice), Kindle, Kobo, Apple Books or Own file.",
            "If you already own that title, the page tells you so and names the store before you save.",
            "Cancel closes the page without saving. On the Mac, Escape is Cancel.",
            "A book you added by hand to a store is replaced by the store's own entry when the store's list later brings the same title.",
        ]),
        Part(title: "A book's page", text: [
            "The page shows the cover, the title, the author, the series and number, each store the book is in, and when you bought it.",
            "Reading status: Not read, Reading or Finished. It is first taken from the store: Apple Books and Kobo report your progress, Kindle does not. Once you set it by hand, your choice stays.",
            "One Open button for each store starts that store's app at the book. If the app cannot jump to the book, it opens the store's app and you find the book there. Opening is known to work for Kindle on the Mac. Apple Books, Kobo and opening from iPhone or iPad have not been tried yet.",
            "Remove from shelf asks first. It is there for wishes, books you added by hand and Kindle books. An Apple Books or Kobo book would come back at the next read, so it has no remove button.",
        ]),
        Part(title: "Lock-free books and sending", text: [
            "A book is marked lock-free only when the app is sure. In this version that means your own files. A store book is never marked lock-free, even if its publisher sells it without a lock.",
            "On the Mac, a lock-free book has three buttons. Open in Apple Books opens the file in Books.",
            "Send to Kobo copies the file into the Dropbox folder Apps › Rakuten Kobo. A Kobo Libra Colour picks it up over Wi-Fi.",
            "Send to Kindle puts a copy in Downloads and opens Amazon's Send to Kindle page. There you choose that file.",
            "On iPhone and iPad the page says that sending is done on the Mac.",
            "Sending has not yet been proven from start to end.",
        ]),
        Part(title: "Wish list", text: [
            "Books you want but do not own. Add them with Add a book, or from a search that found nothing.",
            "When a wished book later turns up in a store's list, it moves from the Wish list to the shelf by itself.",
        ]),
        Part(title: "Settings", text: [
            "Open Settings with the cog button. It holds How it works, What's new, the lists and the version line.",
            "For each store the lists show how many books were found and when. Refresh reads them again. Import Kindle list takes in your Kindle library file.",
            "Done closes Settings.",
        ]),
        Part(title: "Your data and safety", text: [
            "The shelf is one file in the app's iCloud Drive folder. Mac, iPhone and iPad share it.",
            "Your own choices (reading status, wishes) are merged book by book. The newer change wins.",
            "A safety copy is kept on each device once a day, 14 days back.",
            "If a device with an older version of the app meets a newer kind of shelf file, it shows the shelf but changes nothing.",
            "Nothing is sent anywhere, except that cover pictures are fetched from the stores' picture servers.",
        ]),
    ]

    static let news: [Release] = [
        Release(version: "0.2", date: "17 November 2026", items: [
            "Fixed: the Kindle list showed things that are not your books. Before: 16 Kindle “books” on the shelf. What they really were: 1 book you bought, 3 dictionaries that come built into Kindle, and 12 nameless entries whose title was only a row of dashes (Kindle's built-in dictionaries for other languages). Now: built-in entries are left out, meaning anything in Kindle's list without a purchase day and anything whose title has no letters or numbers. On your Mac that leaves 1 Kindle book on the shelf (were 16): the one you bought.",
            "New rule: when a store's list later marks a book on your shelf as a free sample or a built-in item, the book leaves the shelf by itself at the next read. Before, it stayed.",
            "Changed: Settings now says honestly how the Kindle count comes about. It counts the books on the shelf that came from Kindle, not the size of your Kindle library.",
            "Still open: the Kindle app on the Mac does not hold your whole Kindle library, and Amazon's website does not let a helper read it. Your full Kindle list comes in through Settings › Import Kindle list or Add a book.",
        ]),
        Release(version: "0.1", date: "17 November 2026", items: [
            "New: the first version. One shelf for your books from Rakuten Kobo, Apple Books and Amazon Kindle, and for your own files (EPUB and PDF), on Mac, iPhone and iPad.",
            "New: the shelf holds bought ebooks, audiobooks and your own files. Free samples are left out.",
            "New: the Mac reads your Apple Books list from the Books app. On 17 November 2026 it found 299 ebooks, 78 audiobooks and 22 PDFs.",
            "New: the Mac reads your Kobo list from Kobo's Mac app. Not yet checked against your real Kobo list.",
            "New: Kindle books come in three ways: new purchases from the Kindle app on the Mac, a one-time list file of your whole library (Settings › Import Kindle list), and by hand.",
            "New: the lists are read each time the app opens on the Mac, and when you press Refresh in Settings. Settings shows for each store how many books were found and when.",
            "New: iPhone and iPad show the same shelf through iCloud.",
            "New: a book that leaves Apple Books or Kobo leaves your shelf at the next read. An empty list removes nothing. Kindle books are never removed by themselves.",
            "New: the same book in two stores is one book with two store marks. Matching ignores capital letters, accents, subtitles after a colon and a leading “The”.",
            "New: “Owned twice” when you own the same kind (ebook or audiobook) in two stores.",
            "New: the main screen is a stack of shelves with rows of covers that scroll sideways: Reading now, Not read yet (newest first, with the count), one shelf for each series, Lock-free, Audiobooks, Finished and Wish list.",
            "New: series shelves show a note such as “3 owned · missing 2 and 4”.",
            "New: tap a shelf's heading to see all its books in a grid.",
            "New: small coloured dots under each cover show the stores, with an open-lock mark and a headphones mark. A book without a cover shows a coloured tile with its title.",
            "New: search by title, author or series, to check whether you already own a book before you buy it. If nothing matches, you can add it with one button.",
            "New: Add a book, with a choice of Wish list, Kindle, Kobo, Apple Books or Own file. It warns you if you already own the title.",
            "New: a book's page with cover, details, reading status and one Open button for each store.",
            "New: reading status Not read, Reading and Finished. It starts from the store, and your own choice stays once you set it.",
            "New: Remove from shelf for wishes, books added by hand and Kindle books. It asks first.",
            "New: your own files are marked lock-free. On the Mac they have Open in Apple Books, Send to Kobo and Send to Kindle buttons.",
            "New: a wished book moves to the shelf by itself when a store's list brings it.",
            "New: Settings with How it works, What's new, the lists and the version line.",
            "New: the shelf is one file in iCloud Drive. A safety copy is kept on each device once a day, 14 days back. An older app meeting a newer shelf file shows it but changes nothing.",
            "New: hand-drawn icons, a compact look, headings in colour, full-colour main buttons, day and night.",
            "Not tried yet: Open for Apple Books and Kobo, opening from iPhone and iPad, and all three Send buttons from start to end.",
        ]),
    ]
}
