# AMS Reading Companion

One shelf for the books you read in Kobo, Apple Books and Kindle, on iPhone, iPad and Mac.
It reads what those apps know about your library and shows it in one place, in plain words.
It never removes copy protection and never opens or copies protected book files.

Build:   `xcodegen generate`, then open `AMSReadingCompanion.xcodeproj`.
Core tests (seconds):   `cd Core && swift test`.
Release to TestFlight:   `Tools/release.sh <build number> both`   (`ios`, `mac` or `both`).
Before the first upload, put the real App Store Connect app id where `APP_ID_TBD` stands in `Tools/release.sh`.
The app icon is drawn by `python3 Tools/make-icon.py` (an open book, white on plum).
