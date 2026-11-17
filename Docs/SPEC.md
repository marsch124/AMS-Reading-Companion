# AMS Reading Companion — specification, version 0.2 (17 November 2026)

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
- Three ways in: (1) new purchases from the Kindle Mac app after it has synced; (2) a one-time list file of the whole library, Settings › Import Kindle list (`import-kindle-file`; CSV or JSON, with title, author and Amazon's book number per book); (3) by hand with Add a book.

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
- List of all shelves: `shelf-list`; each shelf `shelf-<id>`. Heading in its own colour, a row of covers scrolling sideways.
- Order and colours:
  1. Reading now (`reading`, purple): status Reading AND (set by hand, OR the store gave no last-opened day, OR last opened within 90 days before the newest last-opened day of any owned book). Other started books count as Not read yet on the shelves; their status stays Reading. On 17 Nov 2026 with real data: 77 started, 5 on this shelf.
  2. Not read yet (`unread`, red), newest purchase first, with count, e.g. "Not read yet · 84"
  3. One shelf per series with 2 or more owned books (`series-<name>`, green), in series order, with a note such as "3 owned · missing 2 and 4". Gaps known only below the highest owned number; total size of a series is unknown.
  4. Lock-free (`lockfree`, teal)
  5. Audiobooks (`audio`, amber)
  6. Finished (`finished`, grey), most recent first
  7. Wish list (`wish`, blue), always shown
- A book can stand on several shelves. Empty shelves are left out, except Wish list.
- Tapping a heading shows all its books in a grid (`shelf-all-<id>`).

## 6. Cover marks
- Dots per store: Kobo red-orange, Kindle blue, Apple Books grey, own file teal.
- Open-lock mark when lock-free; headphones mark for an audiobook.
- Legend in How it works.
- No cover picture: coloured tile with the title.

## 7. Search
- Button `open-search`, field `search-field`. Matches title, author, series.
- Results show each owned book with its stores ("do I already own it?").
- No match: "Not on your shelf" and a button to add the typed title (`search-add`).

## 8. Add a book
- Toolbar button `add-book`. Fields `add-title`, `add-author`; choice `add-where`: Wish list (default), Kindle, Kobo, Apple Books, Own file. Buttons `add-cancel`, `add-save`. Mac: Escape = Cancel.
- If the title is already owned, the page says so and names the store before saving.
- A book added by hand to a store is replaced by the store's own entry when the store's list later brings the same title.

## 9. Book page (`book-page`)
- Shows cover, title, author, series and number, each store, when bought.
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

## 12. Settings
- Button `settingsButton`. Items: How it works (`howItWorks`), What's new (`whatsNew`), the lists (section 3), version line (`versionLine`, e.g. "AMS Reading Companion 0.1 (1)"), Done (`settingsDone`).

## 13. Data and safety
- The shelf is one file in the app's iCloud Drive folder, shared by Mac, iPhone, iPad.
- Own choices (status, wishes) merge per book; the newer change wins.
- A safety copy per device once a day, 14 days back.
- An older app version meeting a newer data format shows the shelf but changes nothing.
- Nothing is sent anywhere except cover pictures fetched from the stores' picture servers.

## 14. Look
- Hand-drawn icons, compact, colourful headings, full-colour main buttons, day and night.

## 15. Not proven yet
- Kobo list against the real Kobo library.
- Open for Apple Books and Kobo; all opening on iPhone and iPad.
- Send to Apple Books, Kobo and Kindle end to end.

## 16. Later (not in 0.1)
- Highlights and notes.
- Prices and "where to buy".
- Total size of a series.
- Sending from iPhone.
- Lock-free marks for store books.

## 17. Version history
- 0.1 (17 Nov 2026): first version.
- 0.2 (17 Nov 2026): fix. Built-in Kindle entries left out (16 entries became 2); samples and built-in items marked later leave the shelf; honest Kindle count in Settings.
