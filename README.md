# AMS Reading Companion

One shelf for the books you read in Kobo, Apple Books and Kindle, on iPhone, iPad and Mac.
It reads what those apps know about your library and shows it in one place, in plain words.
It never removes copy protection and never opens or copies protected book files.

Version 0.8 (18 November 2026) also has: the shelves "New on the shelf" and "Waiting longest", your authors, the stores' collections (Apple Books, Kobo) as tags, "Put away", joining two books, changing several books at once, a choice of the parts of the main screen, tick boxes for to dos, and the library check on a series' page. The shelf file has format 5: a device still on 0.7 shows the shelf but changes nothing until updated.
Version 0.7 (18 November 2026) also has: search in the notebook, a quote of the day on the main screen, a "Just finished" card (stars and a few words), "Send these" for the notes that show, a shelf "Read + listen", a cover wall switch on shelf pages, and "At the library?" on wish-list books (Sweden's LIBRIS catalogue). The shelf file stays at format 4. The tour covers versions 0.4 to 0.7.
Version 0.6 (18 November 2026) also has: a big filter (menus above all your books, kept as shelves of your own), the author's page and the series' page, your own tags, a choice and order of the shelves, "Surprise me", progress on the covers, correcting a book's title, author and series, what a book is about, what changed with each read of a store's list, and reading notes (type, speak or take a photo of the page; share one note or a whole book's notes). The shelf file has format 4: a device still on 0.5 shows the shelf but changes nothing until updated.
Version 0.5 (17 November 2026) added: an Up next list, "Your reading" (books finished per year with a goal, and numbers about the shelf), the language of every book, a Home Screen widget (iPhone and iPad), search from the device's own search, packing of own EPUB folders when sending, a series length you can type, and the shelf saved as a PDF list or a table.
The code is public. No real book titles are in it; the sample and the tests use made-up books.

Build:   `xcodegen generate`, then open `AMSReadingCompanion.xcodeproj`.
Core tests (seconds):   `cd Core && swift test`.
Release to TestFlight:   `Tools/release.sh <build number> both`   (`ios`, `mac` or `both`).
Before the first upload, put the real App Store Connect app id where `APP_ID_TBD` stands in `Tools/release.sh`.
The app icon is drawn by `python3 Tools/make-icon.py` (an open book, white on plum).
