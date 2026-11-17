# AMS Reading Companion

One shelf for the books you read in Kobo, Apple Books and Kindle, on iPhone, iPad and Mac.
It reads what those apps know about your library and shows it in one place, in plain words.
It never removes copy protection and never opens or copies protected book files.

Version 0.5 (17 November 2026) also has: an Up next list, "Your reading" (books finished per year with a goal, and numbers about the shelf), the language of every book, a Home Screen widget (iPhone and iPad), search from the device's own search, packing of own EPUB folders when sending, a series length you can type, and the shelf saved as a PDF list or a table. The shelf file has format 3: a device still on 0.4 shows the shelf but changes nothing until updated.
The code is public. No real book titles are in it; the sample and the tests use made-up books.

Build:   `xcodegen generate`, then open `AMSReadingCompanion.xcodeproj`.
Core tests (seconds):   `cd Core && swift test`.
Release to TestFlight:   `Tools/release.sh <build number> both`   (`ios`, `mac` or `both`).
Before the first upload, put the real App Store Connect app id where `APP_ID_TBD` stands in `Tools/release.sh`.
The app icon is drawn by `python3 Tools/make-icon.py` (an open book, white on plum).
