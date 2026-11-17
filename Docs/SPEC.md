# AMS Reading Companion — specification, version 0.3 (17 November 2026)

Platforms: iPhone, iPad, Mac.

## 1. Purpose
- One shelf for every book owned in three stores (Rakuten Kobo, Apple Books, Amazon Kindle) plus own files.
- Shows what is owned and where; prevents buying a book twice; helps move lock-free books.
- Never removes a store's copy lock. A locked book opens only in its own store's app or reader.

## 2. What is on the shelf
- Bought ebooks, audiobooks, own files (EPUB, PDF).
- Free samples are left out.

## 3. Where the lists come from
- The Mac collects the lists each time the app opens and when Refresh is pressed in Settings (`refresh-lists`).
- Settings shows per store the number of books found and when (`import-apple`, `import-kindle`, `import-kobo`).
- iPhone and iPad cannot read the stores; they show the same shelf through iCloud.
- Workflow: after buying, open the store's Mac app once so it syncs, then open the app on the Mac.

### 3.1 Apple Books
- Whole list, read from the Books app on the Mac.
- 17 Nov 2026: 299 ebooks, 78 audiobooks, 22 PDFs; 23 of them own files.

### 3.2 Kobo
- Whole list, read from Kobo's Mac app (installed 17 Nov 2026; sign in once, let it sync).
- NOT YET checked against the real Kobo list.

### 3.3 Kindle
- The Kindle Mac app keeps only a small list from its latest sync, not the library. On 17 Nov 2026 it listed 16 entries: 1 bought book, 3 built-in dictionaries and 12 nameless entries (title only dashes). After the rule below, 1 remains: the bought book. (One dictionary appears twice in the list, once with and once without a purchase date; the reader takes the first, so it is left out too.)
- A Kindle entry is treated as built-in and left out when its purchase date is empty or its title has no letter or digit; personal documents (type PDOC) are exempt.
- Settings counts the books on the shelf that came from Kindle, not the size of the Kindle library.
- Amazon's website cannot be read by a helper; the full Kindle list comes in through Import Kindle list or Add a book.
- Three ways in: (1) new purchases from the Kindle Mac app after it has synced; (2) a one-time list file of the whole library, Settings › Import Kindle list (`import-kindle-file`; Amazon's page saved as a PDF, or a CSV or JSON file with title, author and Amazon's book number per book); (3) by hand with Add a book.

### 3.3.1 Amazon PDF reader (`KindlePDFText`, 0.3)
- The owner signs in at Amazon in his own browser, opens "Manage Your Content and Devices" › Books (sorted by Acquired) and saves the page as a PDF. The app reads the PDF's text (`PDFText`); no network.
- File extension `.pdf` selects this reader. The text must look right (contains "Manage Your Content and Devices" or a line "Acquired/Purchased/Borrowed on <Month> <d>, <yyyy>"); otherwise the note says it is not Amazon's book list. An unreadable PDF: "That PDF could not be read."
- Reading rules: each acquired-date line closes one book; the two text lines directly above it are the title (earlier) and the author (later). Noise lines (buttons, page numbers, "Shared with", "In 1 Device", timestamps, links, copyright) are skipped. A line "READ" right after a book marks it Finished. Books with the same title letters and author within one file are taken once. The book's store id is `title-<letters of the title>`; kind ebook; purchase date from the acquired line (noon UTC).
- "Showing 1 to 25 of 33 items": when the total is larger than the shown count, the note adds "Amazon shows 25 of your 33 books per page: save its next page as a PDF too."
- Result note in Settings (`import-file-note`): "<n> Kindle books in the file: <a> new on the shelf, <b> were already there." Nothing found: "No books found in that file. …"
- A device with a newer shelf file (read-only) cannot import and says so.
- Repeat rule: a book a list file brings again (same title, same store, not a hand copy) adds no second copy of that store; only missing details are filled in.

### 3.4 Removal rules
- Apple Books and Kobo lists are the truth: a book that leaves a list leaves the shelf at the next read.
- An empty list (for example signed out) removes nothing.
- An item a reader marks as sample/built-in is never added, and a copy with the same store id already on the shelf from that same reader is removed (the book goes with it when that was its only copy and it is not a wish).
- Kindle books are never removed automatically.

## 4. One book, several stores
- Same title and author in two stores = one book with two store marks.
- Matching ignores capitals, accents, subtitle after a colon, a leading "The"; "Herbert, Frank" = "Frank Herbert".
- Same kind (ebook or audiobook) in two stores: "Owned twice". Ebook plus its audiobook is not "twice".

## 5. Main screen
- List of all shelves: `shelf-list`; each shelf `shelf-<id>`; each cover tile `book-<shelf id>-<book id>`. Heading in its own colour, a row of covers scrolling sideways. Above the shelves: the "What next?" card (5.1).
- Order and colours (all rules use owned books, i.e. with at least one copy, not removed):
  1. Reading now (`reading`, purple): status Reading AND not gave up AND (set by hand, OR the store gave no last-opened day, OR last opened within 90 days before the newest last-opened day of any owned book). Newest opened first.
  2. Not read yet (`unread`, red): status Not read only (since 0.3 started books are no longer here), newest purchase first, with count, e.g. "Not read yet · 84".
  3. One shelf per series with 2 or more owned books (`series-<plain name>`, green), in series order, with the series note (5.2).
  4. Set aside (`aside`, brown): status Reading AND not gave up AND not on Reading now (started, not opened in the 90 days before the latest reading). Newest opened first; title "Set aside · n". Reading now and Set aside never share a book. Before 0.3 these stood under Not read yet (real data 17 Nov 2026: 72).
  5. Lock-free (`lockfree`, teal), by title
  6. Audiobooks (`audio`, amber), by title
  7. Bought twice (`twice`, pink), by title: a book with copies of the same kind (to read, or to listen to) in two different stores; own files do not count. Real data 17 Nov 2026: 7, of which 3 Kindle + Apple Books.
  8. Finished (`finished`, grey), most recent first
  9. Gave up (`gaveup`, grey), by title: gave-up flag set AND status Reading.
  10. Wish list (`wish`, blue), always shown, newest first
- A book can stand on several shelves. Empty shelves are left out, except Wish list.
- Tapping a heading shows all its books in a grid (`shelf-all-<id>`), with sort and filter (5.3).

### 5.1 What next? (`whatnext-card`, button `whatnext-another`)
- `whatNext(limit 8)` gives suggestions in this order, each book once, only owned books with status Not read:
  1. For each finished book that has a series (most recently opened first): `nextInSeries` is an owned book with status Not read: "Next in <series>, after “<title>”".
  2. The newest purchase (needs a purchase date): "Your newest book".
  3. The remaining Not-read books with a purchase date, oldest purchase first: "Waiting since <Month yyyy>".
- The card shows the first idea; "Another" shows the next and wraps around; shown only when there are 2 or more ideas. No ideas: no card. Tapping the card opens the book.

### 5.2 Series note
- When a catalogue told the series length (`total` between max(highest number owned, books owned) and 200): "<owned> of <total>" and the gaps count up to the total. Otherwise "<owned> owned", with gaps only below the highest owned whole number.
- Then " · missing 2, 4 and 7" when 1 to 8 numbers are missing; with 9 or more missing, or a highest number over 200, the note has no "missing" part.
- Series knowledge is kept in the shelf file per series (plain name → total, volumes, date checked). See 14.1.

### 5.3 Sort and filter (shelf page)
- Three menus: store (`filter-store`: all, Kobo, Kindle, Apple Books, Own file), kind (`filter-kind`: Read or listen / To read / To listen), order (`filter-order`: Shelf order / By title / By author / Newest first). They start plain each time the page opens.
- To read: books with no copies (wishes) or with a non-audio copy. To listen: books with an audiobook copy. By author: author's last name, then title. Newest first: latest purchase date.
- When not plain: "Showing n of m." (`filter-count`), or "No book of this shelf fits."

## 6. Cover marks
- Dots per store: Kobo red-orange, Kindle blue, Apple Books grey, own file teal.
- Open-lock mark when lock-free; headphones mark for an audiobook.
- Legend in How it works.
- No cover picture: coloured tile with the title.

## 7. Search
- Button `open-search`, field `search-field`. Matches title, author, series.
- Matching: every typed word must be found in title, author, series or the owner's note (0.3: notes). Results show each book with its stores ("do I already own it?"); wishes after owned books, marked "Wish".
- Other identifiers: `search-clear`, `search-done`, `search-hint`, `search-count`, `search-none`, `result-<book id>`.
- No match: "Not on your shelf" and a button to add the typed title (`search-add`).

## 8. Add a book
- Toolbar button `add-book` (Mac). On iPhone and iPad the plus is a menu `add-menu` with "Add a book" (`add-book`) and "Scan a barcode" (`open-scan`, see 8.1). Fields `add-title`, `add-author`; choice `add-where`: Wish list (default), Kindle, Kobo, Apple Books, Own file. Buttons `add-cancel`, `add-save`. Mac: Escape = Cancel.
- If the title is already owned, the page says so and names the store before saving.
- A book added by hand to a store is replaced by the store's own entry when the store's list later brings the same title.
- Other identifiers: `add-owned`, `add-title-missing`.

### 8.1 Scan a barcode (iPhone and iPad only, `scan-*`)
- Sheet "Scan a book" (`open-scan` opens it; Done `scan-done`). Camera `scan-camera` (VisionKit data scanner, EAN-13 only); when there is no camera: "No camera here. Type the number under the barcode." (`scan-nocamera`).
- A code from the camera counts only when it has 13 digits and starts with 978 or 979; the same code within 3 seconds is ignored.
- Typed number (`scan-number`, button `scan-lookup`): 10 or 13 digits (dashes and spaces ignored); otherwise "Type the 10 or 13 digits…" (`scan-number-short`). The check digit must be right (ISBN-10 or ISBN-13), otherwise nothing is found.
- Lookup (`ISBNLookup`, see 14.1): Open Library first, then (13 digits only) Apple Books (iTunes Lookup, Sweden). While looking: `scan-looking`.
- Outcome (`scan-result`): owned: "You own this" + cover, stores (`scan-owned`); a wish with that title: "Already on your wish list" (`scan-wished`); otherwise "Not on your shelf" (`scan-new`) with "Add to wish list" (`scan-add-wish`; then `scan-added`); number unknown: "This number is not in the book catalogue." (`scan-unknown`) with "Add by hand" (`scan-add-hand`).
- Not on the Mac: there the plus button only adds a book by hand.

## 9. Book page (`book-page`)
- Shows cover, title, author, series and number, each store, when bought.
- Gave up (`book-gave-up`, "Gave up on it"): shown when the status is Reading or the book is gave-up. It sets gave-up and status Reading by hand: the book leaves Reading now and Set aside and stands on Gave up. "Pick it up again" (`book-pick-up`) clears it (the book returns to Reading now or Set aside by the 90-day rule). Setting a status by hand clears the gave-up flag.
- Your stars and note (`book-note-edit`, `book-stars`, `book-note`, stars `star-1`…`star-5`): "Edit" opens a sheet "Stars and note" with star row, one text field `note-text`, Cancel `note-cancel` (Escape on the Mac) and Save `note-save`. Stars 1 to 5 (tap the last filled star to take one away); a note is one line of text (trimmed; empty = none). Read-only shelf: no Edit.
- Next in the series (`next-owned`, `next-missing`, `next-add-wish`): only when the book has a series and a whole number. `nextInSeries`: (1) an owned book of the same series (plain name) with number +1 → cover, "Book n: title", "On your shelf · not read/reading/finished", tap opens it; (2) else the catalogue's volume n+1 → "Book n: title" + "Not on your shelf." + "Add to wish list" (author of this book); (3) else, if the catalogue knows the total: n+1 ≤ total gives "Book n" only, beyond the total gives nothing; (4) else, with no catalogue knowledge, "Book n" only when a later book is on the shelf. After adding: "Added to your wish list."
- Wish: "Where to buy" (`price-apple`, `price-apple-none`, `price-kobo`, `price-kindle`): see 11.
- Reading status: Not read, Reading, Finished (`status-unread`, `status-reading`, `status-finished`). First taken from the store (Apple Books and Kobo report progress; Kindle does not); once set by hand, the choice stays.
- Open per store (`open-<store>`): starts that store's app at the book. If it cannot jump to the book, it opens the store's app. Known to work: Kindle on the Mac. NOT proven: Apple Books, Kobo, all opening on iPhone and iPad.
- Remove from shelf (`book-remove`, asks first): for wishes, books added by hand, Kindle books. Not shown for Apple Books or Kobo books (they would return at the next read).

## 10. Lock-free books and sending
- A book is lock-free only when the app is sure: own files. A store book is never marked lock-free in 0.1, even if sold without a lock.
- Send buttons, Mac only in 0.1:
  - "Open in Apple Books" (`send-apple`)
  - "Send to Kobo" (`send-kobo`): copies the file into the Dropbox folder Apps › Rakuten Kobo; a Kobo Libra Colour picks it up over Wi-Fi.
  - "Send to Kindle" (`send-kindle`): puts a copy in Downloads and opens Amazon's Send to Kindle page, where the file is chosen.
- iPhone and iPad: the page says sending is done on the Mac.
- Sending is NOT proven end to end.

## 11. Wish list
- A wished book that later appears in a store's list moves from the Wish list to the shelf by itself.
- Where to buy (wish page): asks Apple Books once when the page opens (title + author, Sweden, ebooks, `PriceLookup.apple`): the best-ranked edition of the same book that is not free; a free edition only when no other; shows "Apple Books · <price as Apple formats it, SEK>" as a link to the book. No answer: "Apple Books shows no price for this title in Sweden." Not asked in `-sampleData`.
- "Look on Kobo" opens kobo.com/se/en/search and "Look on Kindle" opens amazon.com Kindle-books search (his Kindle account is on amazon.com) (digital-text), each in the browser with title + author typed in. Kobo and Kindle do not let an app read prices, so none is shown.

## 12. Settings
- Button `settingsButton`. Items: How it works (`howItWorks`), What's new (`whatsNew`), the lists (section 3), version line (`versionLine`, e.g. "AMS Reading Companion 0.3 (n)"), Done (`settingsDone`). Also `refresh-lists`, `import-kindle-file`, `import-file-note`, `lists-help`, `cloud-off`, `howItWorks` page `guidePage`, `whatsNew` page `newsPage`.

## 13. Data and safety
- The shelf is one file in the app's iCloud Drive folder, shared by Mac, iPhone, iPad.
- Own choices (status, wishes) merge per book; the newer change wins.
- A safety copy per device once a day, 14 days back.
- File format: `format` in the shelf file. 0.1 and 0.2 write 1; 0.3 writes 2 (adds per book `rating`, `note`, `gaveUp`; and a `series` table). A version that finds a higher format than it knows shows the shelf but changes nothing (read-only banner `newer-note`; no save, no import, no edit buttons). So a device on 0.2 meeting a format 2 file is read-only until updated. 0.3 reads format 1 files and raises them to 2 on its first change.
- Fields it does not know in an entry make that entry skipped, not the whole file.
- Nothing about the owner's list is sent anywhere. What is sent is in 14.1.

### 13.1 Shelf index and wishes for the Share extension
- Two files in the App Group `group.com.schabbauer.AMSReadingCompanion` (iPhone and iPad only): `shelf-index.json` (the app writes, for every shown book: title, author, store names, wish flag; refreshed when the app comes forward and after each save) and `pending-wishes.json` (the extension writes title, author; the app reads it when it comes forward, adds each as a wish and empties it).

## 14. Share check (iPhone and iPad only, extension "AMS Reading")
- Appears in the Share sheet for a web page, a web address or text (Safari). The extension reads the page's title, else the shared text, else the last words of the address.
- Matching (`ShareMatch.find`): a shelf book matches when the words of its plain title key (no subtitle, accents, capitals, leading "The") appear in the page title in order. A title key with fewer than 5 letters needs the author's last name on the page too. Order: author found first, then longest title, then shelf order.
- Matched: "You own this" (`share-owned`) with title, author and "in <stores>" (and "On your wish list" for wishes). No index yet: "Open AMS Reading once on this device, then try again." (`share-no-index`).
- No match: "Not on your shelf" (`share-none`) with title (`share-title`) and author (`share-author`) guessed from the page title (Amazon, Apple Books and "Title by Author" forms; "Vale, Una" becomes "Una Vale"), and "Add to wish list" (`share-add-wish`). The wish is queued in `pending-wishes.json` and lands on the shelf when the app is next opened. Done: `share-done`.
- Not on the Mac. NOT yet tried on a real iPhone.

## 14.1 Lookups in public catalogues (`ReadingCore/Lookups`)
All requests: 8 seconds time limit; an error or any doubt gives "nothing", never a failure on screen. Only title and author (or the barcode number) are sent; never the owner's list. Not run in `-sampleData`.
- Cover by title (`CoverLookup`): for a book with no cover address and no Apple Books number (Kindle books from a list file, books added by hand, wishes). Asks Apple Books (iTunes Search, Sweden, ebooks, 10 hits) first, then Open Library (search by title and author, needs a cover). Takes the first hit that is the same book (same title key; author last name equal or one unknown). Asked once per book and device (remembered in `coverTriedByTitle`); the answer is stored on the book, so every device gets it. Nothing fits: the coloured title tile stays. Apple Books books ask Apple by their own number (since 0.1).
- Series (`SeriesLookup`): Wikidata's public query service, one request per series. Finds a book the owner has by its English title and author, follows "part of the series" and lists every book of that series by the same author with its number. Answers only when the series name matches the one on the shelf (ignoring words like series, trilogy, saga, the); a number given to two different books makes that series untrusted; several matching series: the biggest. Limits: Wikidata does not know every series or number; then the app keeps "<n> owned". Asked once per series with 2 or more owned books, again after 60 days (also after an empty answer), at most 40 series per start, 0.4 s apart. Stored in the shelf file.
- Barcode (`ISBNLookup`): Open Library (`isbn:<number>`), then Apple Books (iTunes Lookup, 13 digits only, Sweden). Gives title, author, cover. Many books are known; some are not ("This number is not in the book catalogue.").
- Price (`PriceLookup`): Apple Books only (iTunes Search, Sweden). Kobo and Kindle give only search links.
- Catalogues named: Apple Books (itunes.apple.com), Open Library (openlibrary.org, covers.openlibrary.org), Wikidata (query.wikidata.org), Kobo (kobo.com, link only), Amazon (amazon.com, link only).

## 15. Launch arguments (pictures and screen tests)
- `-sampleData`: made-up books, nothing read, nothing saved, no lookups.
- `-search`, `-add`, `-scan`, `-settings`: open that sheet at start.
- `-show <title word>`: start on the page of the first book whose title begins with that word (a book id also works).
- `-shelf <id>`: start on that shelf's page (`reading`, `unread`, `aside`, `twice`, `gaveup`, `wish`, …).
- Flag-only arguments (`-sampleData`, `-search`, `-add`, `-scan`, `-settings`) must come last, after any argument that takes a value.

## 16. Look
- Hand-drawn icons, compact, colourful headings, full-colour main buttons, day and night.

## 17. Not proven yet
- Kobo list against the real Kobo library.
- Share check on a real iPhone.
- Camera scan on a real iPhone.
- Open buttons on iPhone (Apple Books, Kobo; and all opening on iPhone and iPad).
- Sending lock-free books (Open in Apple Books, Send to Kobo, Send to Kindle) end to end.

## 18. Later
- Highlights.
- Sending from iPhone.
- Lock-free marks for store books.
- Kobo and Kindle prices (the stores do not let an app read them).

## 19. Version history
- 0.1 (17 Nov 2026): first version.
- 0.2 (17 Nov 2026): fix. Built-in Kindle entries left out (16 entries became 2); samples and built-in items marked later leave the shelf; honest Kindle count in Settings.
- 0.3 (17 Nov 2026): What next? card; shelves Set aside (72 started books leave Not read yet), Bought twice (7), Gave up; own stars and note; Next in the series; series note "3 of 7" from a public catalogue; covers by title and author; sort and filter on a shelf page; Share check and barcode scan (iPhone and iPad); wish-list prices; Kindle list from Amazon's page saved as PDF; no second copy of a store from a repeated list file; file format 2.
