# AMS Reading Companion — specification, version 0.8 (18 November 2026)

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
  1a. Up next (`upnext`, indigo), right under Reading now (0.5): the Up next list (5.5) in the owner's order; title "Up next · n". Left out when empty.
  1b. (0.6) Kept filters (`saved-<id>`, sea blue), one shelf each in the order they were kept, title "<name> · n", note "No book fits this filter now." when empty (see 5.10).
  1c. (0.8) New on the shelf (`new`, mint): owned books bought, or, when no purchase day is known, first seen, in the last 30 days; newest first; not put away. Stands after Up next. Left out when empty.
  2. Not read yet (`unread`, red): status Not read only (since 0.3 started books are no longer here), newest purchase first, with count, e.g. "Not read yet · 84".
  2a. (0.8) Waiting longest (`waiting`, rust): status Not read AND never opened AND bought a year or more ago; the longest wait first; at most 20. Stands after Not read yet. Left out when empty.
  3. One shelf per series with 2 or more owned books (`series-<plain name>`, green), in series order, with the series note (5.2).
  4. Set aside (`aside`, brown): status Reading AND not gave up AND not on Reading now (started, not opened in the 90 days before the latest reading). Newest opened first; title "Set aside · n". Reading now and Set aside never share a book. Before 0.3 these stood under Not read yet (real data 17 Nov 2026: 72).
  5. Lock-free (`lockfree`, teal), by title
  6. Audiobooks (`audio`, amber), by title
  7. Bought twice (`twice`, pink), by title: a book with copies of the same kind (to read, or to listen to) in two different stores; own files do not count. Real data 17 Nov 2026: 7, of which 3 Kindle + Apple Books.
  7a. (0.7) Read + listen (`pairs`): titles owned both to read (an ebook or an own file, in any store) and to listen to (an audiobook, in any store). Not the same as Bought twice (same kind in two stores). Hidden or moved in Choose your shelves like the others (5.14). The book page says "You own this to read and to listen to".
  8. Finished (`finished`, grey), most recent first
  9. Gave up (`gaveup`, grey), by title: gave-up flag set AND status Reading.
  10. Wish list (`wish`, blue), always shown, newest first
- A book can stand on several shelves. Empty shelves are left out, except Wish list.
- 0.6: the usual order above is the default. `mainShelves()` shows the shelves in the owner's order without the hidden ones (5.14); the keys are the shelf ids, with `series` standing for every series shelf. Wish list can be hidden too.
- 0.6: the top bar has the filter button `open-filter` (iPhone and iPad: top left, so the four buttons on the right stay and the title "My Books" keeps its room; Mac: in the top bar). Under the What next? card a line `open-notes` ("Reading notes · n" with the newest note's words; "Reading notes" + "Nothing noted yet" with no notes; left out on an empty shelf) with the pen `new-note` at its right end (six top-bar buttons squeezed the title out on iPhone, seen in the picture round 18 Nov); at the very bottom a small line `open-changes` ("<store>: 3 came, 1 left · 18 Nov", 5.15), left out with nothing noted.
- Tapping a heading shows all its books in a grid (`shelf-all-<id>`), with sort and filter (5.3). 0.6: a series shelf's page has "All parts" (`series-all-parts`, opens 5.12) next to "Set length" (`series-length`); a kept filter's page has "Change" (`kept-change`, opens the sheet `kept-page`, 5.10).

### 5.1 What next? (`whatnext-card`, button `whatnext-another`)
- `whatNext(limit 8)` gives suggestions in this order, each book once, only owned books with status Not read:
  0. (0.5) The Up next books in the owner's order: the first with the reason "First on your Up next list", the others "Number <n> on your Up next list".
  1. For each finished book that has a series (most recently opened first): `nextInSeries` is an owned book with status Not read: "Next in <series>, after “<title>”".
  2. The newest purchase (needs a purchase date): "Your newest book".
  3. The remaining Not-read books with a purchase date, oldest purchase first: "Waiting since <Month yyyy>".
- The card shows the first idea; "Another" shows the next and wraps around; shown only when there are 2 or more ideas. No ideas: no card. Tapping the card opens the book.
- 0.6 "Surprise me" (`whatnext-surprise`, on the card): `surprise(not:)` picks a book by chance among the owned books with status Not read, never the one shown last when another exists; the card then shows it with the reason "A surprise from the books you have not started". "Another" (also shown while a surprise stands) returns to the ideas.

### 5.2 Series note
- When a total is known (a catalogue's, or the owner's own, see 5.8; `total` between max(highest number owned, books owned) and 200): "<owned> of <total>" and the gaps count up to the total. Otherwise "<owned> owned", with gaps only below the highest owned whole number.
- Then " · missing 2, 4 and 7" when 1 to 8 numbers are missing; with 9 or more missing, or a highest number over 200, the note has no "missing" part.
- Series knowledge is kept in the shelf file per series (plain name → total, volumes, date checked). See 14.1.

### 5.3 Sort and filter (shelf page)
- Four menus (0.5: language added): store (`filter-store`: all, Kobo, Kindle, Apple Books, Own file), kind (`filter-kind`: All kinds / To read / To listen), language ("Language": all languages, or one of the languages found among the shelf's books, the most books first), order (`filter-order`: Shelf order / By title / By author / Newest first). They start plain each time the page opens.
- To read: books with no copies (wishes) or with a non-audio copy. To listen: books with an audiobook copy. By author: author's last name, then title. Newest first: latest purchase date.
- When not plain: "Showing n of m." (`filter-count`), or "No book of this shelf fits."

### 5.4 Wide layout (iPad and Mac, 0.4)
- Threshold: the window's width is 760 points or more. Narrower windows (small Mac window, iPad in a narrow split) and the iPhone keep the old behaviour: a tap on a cover pushes the book's page, Back returns. Nothing changes on the iPhone.
- Wide: two parts side by side. Left: the shelves exactly as before (What next? card, coloured headings, rows of covers, the three buttons at the top). Right: the book's page (section 9) without leaving the shelves, in a part `book-pane`. Its width is 38 % of the window's width, at least 340 and at most 440 points.
- A tap on a cover selects that book and shows it on the right; a tap on another cover changes it. The selected cover has a purple frame.
- When the app opens, the first book of Reading now is selected. If there is none, the right part shows the line "Tap a cover and the book shows here." (`book-pane-empty`).
- A tap on a shelf's heading still opens that shelf's page (5, grid with sort and filter) on the left; a tap on a cover there also selects the book on the right. "Next in the series" (9) on the right selects the next book on the right.
- The selection is kept while the app is open and is not saved. A book that leaves the shelf (for example removed) empties the right part.
- Search, Add a book, Scan and Settings are unchanged (sheets). A book opened from Search still opens inside the Search sheet.
- Identifiers: `book-pane` (the right part), `book-pane-empty` (the line shown when no book is chosen).
- No change to the data: file format stays 2; no new lookups.

### 5.5 Up next (0.5)
- Data: `upNext` (ordered list of book ids) and `upNextChanged` (time of the last change) in the shelf file.
- Only a book on the shelf (at least one copy, not removed) with status Not read can stand on the list. Ids that cannot are dropped; each book once.
- Book page: button "Add to Up next" for such a book; when it is on the list, "Take off Up next". Adding puts it at the end.
- Shelf `upnext` (indigo, "Up next · n"), under Reading now. On its page, "Change order" opens a page where books are moved up or down or taken off, with Cancel and Save (Escape on the Mac is Cancel). Save writes the new order and the change time.
- A book that is started (Reading) or finished leaves the list by itself, and the change time is set.
- Merge between devices: the list with the newer `upNextChanged` wins whole; the two lists are not mixed.
- What next? offers the Up next books first (5.1).

### 5.6 Your reading: Year and Numbers (0.5)
- A small button in the top bar of the main screen (the calendar button) opens the page "Your reading" (`year-page`) with a switch (`year-switch`) between "Year", "Numbers" and (0.8) "Authors" (part `year-part-authors`; parts are `part-<name>`). Done: `year-done`.
- Year: one block per year that has a finished book, the latest year first, and always the current year. Heading "<year> · <n> books" (`year-heading-<year>`); under it the finished books, the latest finishing day first, each with stars and the finishing day (`year-book-<id>`).
- Goal: "Set goal" (`year-goal-button`) opens a sheet with a number field (`goal-field`), Cancel (`goal-cancel`) and Save (`goal-save`). The goal is stored for that year (`goals`, year → count, with `goalsChanged`, the time of the last change). A goal holds for the following years until changed: the goal for a year is the one set for it, else the latest one set for an earlier year. Empty or 0 = no goal from that year on. At most 999.
- Goal line (`year-goal-line-<year>`): "<finished> of <goal> · goal reached" when finished is at least the goal. In the current year otherwise: due = goal × day of the year ÷ days in the year, rounded down; finished above due: "· <n> ahead"; below: "· <n> behind"; equal: "· on track". A year that is over shows only "<finished> of <goal>".
- Merge between devices: the goals with the newer `goalsChanged` win whole.
- Finishing day (`finished` on the book; `finishedDay` is the day that counts): today when the owner marks a book Finished; the day the store last saw the book open (`lastOpened`) when a store reports it finished; a book finished before 0.5 (no `finished`) counts on its `lastOpened`. On a finished book's page the day can be corrected (`setFinishedDay`; only a finished book has one). Finished books with no day at all stand under "Day not known" (`year-unknown-heading`).
- Numbers (`numbers-page`): books (owned), wish list, lock-free, bought twice; bars by store (a book in two stores counts in both), by kind (ebooks, audiobooks, PDFs; a book held both ways counts in both), by reading status (Not read yet, Reading now, Set aside or gave up, Finished), by language ("Not known" last), bought per year, finished per year; the average of the owner's stars (`numbers-stars`) when something is rated. Lines: `numbers-line-<title>-<name>`, figures `numbers-figure-<name>`.

### 5.7 Language (0.5)
- Every book can carry `language` (a two-letter code such as `sv`, `de`, `en`) and `languageByHand` (true when the owner set it).
- Source: Apple Books and Kobo tell it for most books (codes like "sv-SE", "swe" or "Swedish" are read as `sv`); Kindle does not. Where no store tells and the owner has not set it, `BookLanguage.guess` fills a careful guess from the title: only Swedish, German or English. "å" in the title = Swedish; "ß" = German; a title with fewer than 12 letters gets no guess (apart from å and ß); otherwise the system's language recognition, limited to those three, must be at least 80 % sure. The guess is not an owner's change (the book's change time stays).
- A language set by hand (`languageByHand`) is never overwritten, by a store or a guess.
- A store's word beats an earlier guess. A book held in two stores keeps the language it has (two stores that disagree must not flip it back and forth).
- Housekeeping after the Mac read the stores' lists (`tidy`, no book's change time moves): a guessed language where there is none; a book finished before 0.5 gets its finishing day fixed to the day it was last opened then (so opening it again later does not move it to another year); books a store has seen started leave the Up next list.
- Between two devices: a language or finishing day found on one side is carried to the other when that side has none; a series total typed by hand on one device stays when the other device asked a catalogue later.
- Book page: "Language" shows it and lets the owner change it. Shelf page: the sort and filter has "Language" (5.3). Numbers counts per language (5.6).

### 5.8 Series length by hand (0.5)
- Series page: "Set length" opens a sheet to type how many books the series has, with Cancel and Save. Stored in the series table (`total`, `byHand` = true, 1 to 200). The heading then reads e.g. "3 of 7 · missing 2, 4, 6 and 7".
- A number by hand is not changed by a catalogue's answer. An empty field (or 0) removes the number (`total` empty, `byHand` false); a catalogue may fill it again.

### 5.9 Save the shelf as a list (0.5)
- Settings › "Save the shelf as a list" (`settings-list-pdf`, `settings-list-table`).
- "PDF": a printable list of every shown book by title, wishes last: title, author, series, stores, status, stars.
- "Table": a comma-separated file a spreadsheet opens (heading line first, one line per book, same order). Columns: Title, Author, Series, Number, Stores, Kind, Language, Status, Finished, Stars, Note, Bought, Lock-free. Status: Not read, Reading, Finished, Gave up or Wish. Days as yyyy-mm-dd. Lock-free: "yes" or empty.

### 5.10 The big filter and kept filters (0.6; `FilterResultsPage`, `FilterMenus`, `BookFilter`, `SavedFilter`)
- Button `open-filter` (iPhone and iPad: top left; Mac: top bar) opens the page "All books" (`results-page`, route `.results`) straight away: every book of the shelf as covers `result-<id>`, and above them one row of small menus (pills). The page is pushed onto the shelves' stack (on a wide screen it shows on the left). Menus: Store (`filter-menu-store`), Kind (`filter-menu-kind`), Language (`filter-menu-language`), Status (`filter-menu-status`), More (`filter-menu-more`). More holds Your stars, Bought, Finished, Tags (each a small menu inside) and Lock-free. Items: `filter-store-<kobo|kindle|apple|own>`, `filter-kind-<ebook|audiobook|pdf>` (To read, To listen, PDF), `filter-language-<code>` and `filter-language-unknown` ("Not known"), `filter-state-<unread|reading|aside|finished|gaveUp|wish>`, `filter-stars-<3|4|5|0>` ("3 or more", "4 or more", "5", "None yet"; one at a time), `filter-bought-<year>` (the 3 latest years) and `filter-bought-earlier`, `filter-finished-<year>` (the 5 latest years), `filter-tag-<plain tag>`, `filter-lockfree`. A menu lists only what the shelf has (a store or kind with no book is left out; Tags and Lock-free only when there are some). Existing `filter-store`, `filter-kind`, `filter-order`, `filter-language`, `filter-count` stay the menus of a shelf page (5.3). Gone since the look "menus above the books": `filter-page`, `filter-show`, `filter-keep`, `results-change`, `results-words`.
- Rule (`books(matching:)`): inside one group a book needs ONE of the choices; across groups ALL groups must fit; an empty group does not narrow. Stars: n = n or more; 0 = no stars yet; 5 = 5. Bought: purchase year among the years, or before the "Earlier" year (the oldest of the 3 shown); a book with no purchase day never fits. Finished: year of `finishedDay`. Tags: any tag of the book (compared plainly, `tagKey`). Status: `state(of:)` gives wish (no copies), not read, reading now, set aside (Reading, outside the 90-day window), gave up, finished. Pool: owned books; with Wish under Status also wishes. Result sorted by title.
- Menus: each choice is a tick; several can be ticked. iPhone and iPad: the menu stays open while ticking; Mac: it closes after each tick. The books change at once; there is no "Show" button. A menu with nothing ticked is an outline with the group's name; with a tick it is full colour and shows the choice ("Kobo", "Kobo +1" with more; More shows "More · 2"). `filter-clear` "Clear" stands at the end of the menu row once something is ticked.
- Count line `results-count` under the menus: "n of m books" (e.g. "42 of 469 books"); with Wish ticked just "n books"; "No book fits." when none. `results-keep` "Keep" in the top bar, once something is ticked (hidden when read-only): name alert (`filter-keep-name`, suggested from the choices in words, at most 40 letters; Cancel / Save), then `results-kept` ("Kept as the shelf “<name>”. It is on the main screen."). A tap on a tag on a book's page (5.13) opens this page with that tag ticked.
- Kept filter: `savedFilters` in the shelf file (id, name, filter, changed, removed). `keepFilter` needs a name and a non-empty filter. The shelf id is `saved-<id>`; the page `shelf-all-saved-<id>`. "Change" (`kept-change`) opens the sheet "Change shelf" (`kept-page`): name `filter-name`, the same row of menus, line `kept-count` ("5 books fit"), `filter-remove` "Remove this shelf" (asks; the books stay; the shelf is marked removed, not deleted), Cancel `filter-cancel` (Escape) and Save `filter-save` (needs a name and choices). A removed filter's page closes itself.
- Between devices: kept filters merge one by one, the newer `changed` wins (a removed one stays as a marker).

### 5.11 The author's page (0.6; `AuthorPage`, route `.author`)
- Book page: the author's name is a button `book-author` (only where the page has a stack to push on: not on a book opened inside Search).
- `books(by:)`: every shown book (owned and wished) whose first author's last name equals (`authorKey`); series first by series and number, then by title; wishes last. Page `author-page`; count line `author-count` ("5 books · 4 on your shelf · 1 wished · 2 finished"); groups "On your shelf" and "Wish list"; rows `author-book-<id>` (cover, title, series · number, state, store marks); empty: `author-empty`.

### 5.12 The series' page (0.6; `SeriesPage`, route `.series`)
- Book page: the series line is a button `book-series` (same limit as the author). Also "All parts" (`series-all-parts`) on a series shelf's page.
- `seriesParts`: every part from 1 to the length in order; length = the catalogue's or the owner's total, else the highest number (max 200). A part is owned, wished (a wish with a number) or missing; books without a whole number come last. Page `series-page`; head: the author most books have; count `series-count` ("3 of 7 owned · 1 finished · 1 wished · 3 missing"; "3 owned" when nothing is missing or wished); parts `series-part-<n>` (number badge, title, state and a tick for an owned part, "On your wish list", or for a missing part the catalogue's title or "Title not known").
- A missing part: `series-wish-<n>` "Wish" (`wishSeriesPart`): a wish with the catalogue's title, else "<Series> <n>", the series' author, series and number set, in its place. A title the owner already has is not doubled (the existing book keeps its own place).
- `series-set-length` "Set length" opens the sheet of 5.8 (hidden when read-only).

### 5.13 Tags (0.6; `TagsPage`)
- `book-tags-edit` ("Add" with none, else "Edit") opens `tags-page`: chips of the book's tags (on) and the tags in use elsewhere (with counts) `tag-<key>`, field `tags-field`, `tags-add`, Cancel `tags-cancel`, Save `tags-save`. `-show <word> -tags` opens it.
- Rules (`cleanTags`): trimmed, inner white space made one space, at most 30 letters, each once by its plain form (no capitals, accents). `allTags()`: tags on shown books, the most used first. Book page: the tags as chips `book-tag-<key>`; a tap opens the result page (5.10) for that tag.
- Search (7) and the big filter (5.10, under More › Tags) find tags.

### 5.14 Choose your shelves (0.6; `ShelvesChoicePage`; renamed "Main screen and shelves" in 0.8, see 5.31)
- Settings › "Choose your shelves" (`settings-shelves`) opens `shelves-page`. One line per key in the owner's order: reading, upnext, kept filters, unread, series (all series shelves as one line, "n series"), aside, lockfree, audio, twice, finished, gaveup, wish; tick `shelves-tick-<key>` (show or hide), arrows `shelves-up-<place>`, `shelves-down-<place>`, count ("empty now", "n books"). `shelves-reset` "Back to the usual order" (applies on Save), Cancel `shelves-cancel` (Escape; "Done" when read-only), Save `shelves-save`.
- Data: `shelfOrder`, `hiddenShelves`, `shelvesChanged`. Empty `shelfOrder` = usual order. A key the order does not know: a kept filter goes to the front, others to the end. A hidden shelf keeps its books; its page still opens from elsewhere. `-page shelves` (with `-settings`) opens it.
- Between devices: the side with the newer `shelvesChanged` wins whole.

### 5.15 What changed (0.6; `ChangesPage`, `ChangeEntry`)
- After each read of a store on the Mac (`apple`, `kobo`, `kindle`), `noteChange` remembers the titles that came and left (at most 40 named, with the full counts `cameCount`, `leftCount`). Not remembered: a store's very first read (no earlier `imports` entry), a read that changed no title, an imported Kindle list file. The latest 40 entries are kept, newest first (also after a merge: put together by id). A shelf from before 0.6 starts empty.
- Settings › "What changed" (`settings-changes`) and the line `open-changes` at the bottom of the main screen open `changes-page`: per entry `changes-entry-<n>` "<store> · <d MMMM yyyy>", "+" lines for books that came, "−" lines for books that left, "and <n> more came/left"; empty: `changes-empty`; Done `changes-done`. `-page changes` opens it.

### 5.16 Reading notes (0.6; `ReadingNote`, `NoteKind`, `NoteEditPage`, `NotesPage`)
- Pen `new-note` (main screen, right end of the "Reading notes" line): a new note for `noteBook` (the first book of Reading now, else the first of Up next, else the first owned); with no book, or read-only, it opens the notebook. Sheet `note-page`: book line `note-book` (opens a picker `notebook-search`, `notebook-row-<id>`, `notebook-none`, `notebook-cancel`; Reading now and Up next while the field is empty), kinds `note-kind-<id>` (with the kind's colour dot) and `note-kinds-edit` ("Your own…"), text `note-text`, `note-type` (focus), `note-speak` (Speak / Stop), `note-photo` (Photo of the page), page field `note-page-field`, `note-trouble`, Cancel `note-cancel` (Escape), Save `note-save` (needs words and a kind). A changed note also has `note-share` (one note as words) and `note-remove` (asks). The book can be changed on an existing note. `-notes` opens the notebook, `-newnote` a new note.
- Speak (`Dictation`): asks once for speech and for the microphone; language of the book (sv, de, en) else the device's; on the device itself where it can; text joins the note. Trouble words in `note-trouble`.
- Photo of the page (`PageTextReader`, `PageLinesPage` `page-lines`): iPhone and iPad take a picture with the camera (the photo library when there is no camera); the Mac opens a picture file. Vision reads the lines (sv, en, de), top to bottom; the owner ticks lines `lines-row-<i>` (`lines-all`, `lines-none`), `lines-use` "Use <n> lines" (all lines when none ticked), `lines-cancel`; a line ending in a hyphen joins the next without it. States: `lines-reading`, `lines-none-found`.
- Data: notes `notes` (id, bookID, text, kind, page, made, changed, removed); kinds `noteKinds` (id, name, colour) with `noteKindsChanged`. Start kinds: Quote (purple), Thought (teal), To do (red), Word to look up (blue); own kinds get green, pink, indigo, amber, brown in turn. A removed kind's notes stand under "Other" (`kindsInUse`). A removed note is a marker (`removed`); notes of a book no longer shown are hidden. Note text: a kind name at most 30 letters, a name already there adds nothing.
- Book page: "Reading notes · n" with `book-new-note`, rows `book-note-<id>`, and `book-notes-send` ("Send all <n> notes as one page"; one note: "Send this note as a page").
- Notebook `notes-page` (Done `notes-done`, `notes-new` "New note", empty `notes-empty`): all notes, the newest first (`notes-note-<id>`), kinds on top as chips `notes-kind-all`, `notes-kind-<id>` (`notes-kind-other`) with counts; a tap opens the note (not when read-only). The arrangement is the owner's pick of 18 Nov 2026 (`NotesPage.arrangement = .notebook`; "book by book" is kept in the code, unused).
- Kinds page `kinds-page` (Settings › "Kinds of notes" `settings-kinds`, and "Your own…"): per kind name field `kind-name-<id>` (rename on Return or leaving the field) and `kind-remove-<id>` (asks), new `kind-new` + `kind-add`, Done `kinds-done`. `-page kinds` (with `-settings`) opens it. The last kind cannot be removed (its remove mark is hidden; `removeKind` refuses). Read-only: fields and marks are disabled.
- Sending (`noteText`): body (a quote in quotation marks), blank line, "— <Kind>, “<Title>” by <Author>, page <n>" (a bare number becomes "page n", else the owner's words). `notesPage`: Markdown "# Notes on “<Title>”", a line "<Author> · n notes · <d MMMM yyyy>", then "## <Kind>" per kind in use, the oldest note first; a quote as "> “…”", others as "- …", with "(page n)". Sent with the system Share sheet (any app, for example PARAGON).
- Between devices: notes merge one by one (newer `changed` wins); the kinds list wins whole by `noteKindsChanged`.

### 5.17 Correct a book (0.6; `CorrectBookPage`)
- Book page, bottom: `book-correct` ("Correct title, author or series", with "(corrected by you)" once done; hidden when read-only). Sheet `correct-page`: `correct-title`, `correct-author`, `correct-series`, `correct-number`, Cancel `correct-cancel`, Save `correct-save` (needs a title). `-show <word> -correct` opens it.
- `correct`: sets title (empty keeps it), author, series and number (an empty series clears both) and `detailsByHand`. From then on a store's list no longer changes title, author or series of that book (`take`, `fill`). The first correction keeps the words from before in `storeDetails` (title, author, series, number); by them the book is still matched when another store lists it or the Share check asks (`isSame`). `uncorrect` (`correct-undo` "Use the store's words again", only for a corrected book) puts those words back at once, clears `storeDetails` and `detailsByHand`.

### 5.18 What it is about (0.6; `AboutLookup`)
- Book page part "What it is about" (`book-about`, `book-about-more` More/Less when over 260 letters; text at most 5 lines when closed) with "From the publisher, as a catalogue lists it." Shown only when a text is known. Data per book: `about`, `aboutChecked`.
- When a book's page opens (`lookUpAbout`): asked when `about` is empty and not asked in the last 30 days; not in `-sampleData`, not read-only. Apple Books first (iTunes Search, Sweden, ebook then audiobook, first hit that is the same book with a description), then Open Library (search, then the work's description). Only title and author are sent. Cleaned to plain text (HTML removed, entities decoded), at most about 2,000 letters, at least 40. "Found" stores the text; "nothing known" stores `aboutChecked`; "could not reach" stores nothing (asked again later). Not the owner's change: the book's `changed` stays; a text found on one device is carried to the other.

### 5.19 Progress on covers (0.6)
- `coverProgress`: for a book with status Reading, not gave up, whose store reported `progress` between 1 % and 99.5 %. A thin bar along the bottom of its cover tile (`cover-progress`; white on dark, width = share read) on every shelf and grid; the book page says "<n> % read" (`book-progress`). The percent comes from the store (Apple Books and Kobo), read on the Mac; Kindle gives none.

### 5.20 Search in the notebook (0.7)
- A search field on top of `notes-page`. It shows the notes that hold every word typed (all words must match), in the note's text, its page, its kind's name, or the title or author of its book. Capitals and accents do not matter. It works together with the kind chips (`notes-kind-all`, `notes-kind-<id>`, `notes-kind-other`): a note must fit both. Nothing is stored.

### 5.21 Quote of the day (0.7)
- Under the `open-notes` line on the main screen: one of the owner's own notes of the kind Quote, with the book it is from. Same quote all day; the next day the next quote, in turn, so every quote gets its day. A tap opens the note. No quotes written (or a read-only shelf cannot open it): no line. Nothing is stored; the pick follows from the day and the list of quotes.

### 5.22 "Just finished" card (0.7)
- On top of the main screen: when a book became Finished within the last 14 days and has no stars yet, a card "Just finished · <title>. How was it?" with five stars, one line for a few words, "Save" and "Not now". Save writes the stars and the words as the book's own "Stars and note" (the same fields as 9). "Not now" is remembered on that device only (not in the shelf file). Giving stars on any device ends the question everywhere. One card at a time, the latest finished book first.

### 5.23 "Send these" (0.7)
- In the notebook: a button sends exactly the notes that show (after search and kind) as one page, book by book; each note with its kind in front and its page. Sent with the system Share sheet (any app, for example PARAGON).

### 5.24 Cover wall (0.7)
- A shelf's page (`shelf-all-<id>`) and the page "All books" (5.10) have one small button in the top bar that switches between the list and a wall: a full grid of covers with no words. A tap on a cover opens the book. The choice is remembered on the device; one switch for all shelves; not in the shelf file.

### 5.25 Library check (0.7)
- On the page of a wish-list book: "At the library?" asks LIBRIS (Sweden's national library catalogue) whether libraries have the title, and shows in which forms (paper book, e-book, audiobook) with a button "Open at the library" that opens the catalogue's page for the title. Only the title and the author are sent. It tells that libraries in Sweden list the title, not which one. When the catalogue cannot be reached it says so; nothing is remembered as "not there".

### 5.26 Your authors (0.8; `authors-list`, `authors-search`, `authors-order`, `year-part-authors`)
- Third part of "Your reading" (5.6): one row per author of the owned books and wishes, with the counts owned, read, reading, not read and wished. Search field `authors-search`; order `authors-order`: "Most books" or "A to Z". A tap opens the author's page (5.11). Authors are told apart by last name plus the first letter of the first name. Launch option `-authors`.

### 5.27 The stores' collections as tags (0.8)
- The Mac reads, together with the book lists, the owner's own collections in Apple Books and own shelves in Kobo, and keeps them on the copy in the shelf file (new per-copy field). They show as tags on the book (5.13) and work in the big filter (5.10, More > Tags) and in the search (7) like own tags. The stores' built-in ones (Books, Audiobooks, Finished, Want to Read and the like) are left out. They cannot be removed in the app; the tag page lists them apart with the line "These come from your collections in Apple Books or Kobo. Change them there."
- Not proven against the owner's real Apple Books and Kobo.

### 5.28 Put a book away (0.8; `book-putaway`, `book-takeout`, `settings-putaway`, `putaway-page`)
- Book page of an owned book: "Put away" (`book-putaway`, asks first) sets a put-away mark on the book. A put-away book leaves every shelf, count, What next? and Surprise me; Search still finds it, marked "Put away". Settings > "Put away · N" (`settings-putaway`) opens `putaway-page`, listing them with "Take out again"; the book page offers the same (`book-takeout`). Launch option `-settings -page putaway`.

### 5.29 Join two books (0.8; `book-join`, `join-page`, `join-save`)
- Book page: "Same book as another..." (`book-join`) opens `join-page`: choose the other book (likeliest first: same author), then "Join" (`join-save`), which asks once more. The other book's copies, notes, tags and Up next place move to this book; stars, note, cover, series and finishing day are taken over where this book has none; the further-along status wins. The other book leaves the shelf. It cannot be undone; the stores' lists keep both copies on the one book from then on.
- Not proven on two real books.

### 5.30 Change several at once (0.8; `select-start`, `select-done`, `select-all`, `select-tag`, `select-status`, `select-upnext`, `select-putaway`)
- A shelf's page and the big filter's page have "Select" (`select-start`). Tapping a cover ticks it (list and cover wall); "All" (`select-all`); "Done" (`select-done`). A bar at the bottom: Tag... (`select-tag`), Status Not read / Reading / Finished (`select-status`), Up next (`select-upnext`), Put away (`select-putaway`, asks first).

### 5.31 Main screen and shelves (0.8; was "Choose your shelves", 5.14)
- Settings > "Main screen and shelves" (`settings-shelves`) starts with five switches: Just finished card, What next? card, Reading notes line, Quote of the day, What changed line. Saved with Save like the shelves; kept in the shelf file (the list of switched-off parts); the same on all devices. The shelf list (5.14) also holds `new` and `waiting`.

### 5.32 To do tick boxes (0.8; `note-tick-<id>`, `notes-todo-count`)
- A note of the kind To do has a tick box `note-tick-<id>`: tap to tick it off or open it again; the note stays, struck through ("done" on the note, kept in the shelf file). The Reading notes line on the main screen says how many to dos are open ("2 to do"; `notes-todo-count`); the To do chip in the notebook counts the open ones; the note's edit page has a switch "Done".

### 5.33 Library check for a series (0.8; `series-library-<number>`)
- On a series' page (5.12) each missing or wished part that has a title has "At the library?" (`series-library-<number>`), the same check as 5.25 (LIBRIS; forms, not which library; only title and author are sent).

## 6. Cover marks
- Dots per store: Kobo red-orange, Kindle blue, Apple Books grey, own file teal.
- Open-lock mark when lock-free; headphones mark for an audiobook.
- Legend in How it works.
- No cover picture: coloured tile with the title.

## 7. Search
- Button `open-search`, field `search-field`. Matches title, author, series.
- Matching: every typed word must be found in title, author, series, the owner's note (0.3: notes) or his tags (0.6, 5.13). Results show each book with its stores ("do I already own it?"); wishes after owned books, marked "Wish".
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
- Shows cover, title, author, series and number, language (0.5, changeable, see 5.7), each store, when bought.
- 0.5: "Add to Up next" / "Take off Up next" for an owned book not started (5.5); on a finished book the finishing day can be corrected (5.6).
- Gave up (`book-gave-up`, "Gave up on it"): shown when the status is Reading or the book is gave-up. It sets gave-up and status Reading by hand: the book leaves Reading now and Set aside and stands on Gave up. "Pick it up again" (`book-pick-up`) clears it (the book returns to Reading now or Set aside by the 90-day rule). Setting a status by hand clears the gave-up flag.
- Your stars and note (`book-note-edit`, `book-stars`, `book-note`, stars `star-1`…`star-5`): "Edit" opens a sheet "Stars and note" with star row, one text field `stars-note-text`, Cancel `stars-note-cancel` (Escape on the Mac) and Save `stars-note-save`. Stars 1 to 5 (tap the last filled star to take one away); a note is one line of text (trimmed; empty = none). Read-only shelf: no Edit.
- Next in the series (`next-owned`, `next-missing`, `next-add-wish`): only when the book has a series and a whole number. `nextInSeries`: (1) an owned book of the same series (plain name) with number +1 → cover, "Book n: title", "On your shelf · not read/reading/finished", tap opens it; (2) else the catalogue's volume n+1 → "Book n: title" + "Not on your shelf." + "Add to wish list" (author of this book); (3) else, if the catalogue knows the total: n+1 ≤ total gives "Book n" only, beyond the total gives nothing; (4) else, with no catalogue knowledge, "Book n" only when a later book is on the shelf. After adding: "Added to your wish list."
- Wish: "Where to buy" (`price-apple`, `price-apple-none`, `price-kobo`, `price-kindle`): see 11.
- 0.6: author and series line are buttons (5.11, 5.12); "<n> % read" (5.19); parts Tags (5.13), Reading notes (5.16), What it is about (5.18); `book-correct` at the bottom (5.17). Order of the parts: status, gave up, Up next, finished day, language, stars and note, tags, reading notes, what it is about, next in the series, where to buy, copies, sending, correct, remove.
- Reading status: Not read, Reading, Finished (`status-unread`, `status-reading`, `status-finished`). First taken from the store (Apple Books and Kobo report progress; Kindle does not); once set by hand, the choice stays.
- Open per store (`open-<store>`): starts that store's app at the book. If it cannot jump to the book, it opens the store's app. Known to work: Kindle on the Mac. NOT proven: Apple Books, Kobo, all opening on iPhone and iPad.
- 0.8: "Put away" (5.28) and "Same book as another..." (5.29) on an owned book; collection tags (5.27).
- Remove from shelf (`book-remove`, asks first): for wishes, books added by hand, Kindle books. Not shown for Apple Books or Kobo books (they would return at the next read).

## 10. Lock-free books and sending
- A book is lock-free only when the app is sure: own files. A store book is never marked lock-free in 0.1, even if sold without a lock.
- Own EPUB books that Apple Books keeps as a folder (0.5, `EPUBPacker`): "Send to Kobo" and "Send to Kindle" on the Mac first pack the folder into one proper `.epub` file (the `mimetype` entry first, stored; the rest compressed), then send that file. Apple's own extra files (names starting with `iTunes`) and hidden files (names starting with a dot) are left out. The folder is only read, never changed. Before 0.5 the app refused such a book ("opened-up folder").
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
- 0.8: "Choose your shelves" is now "Main screen and shelves" (5.31); new line "Put away · N" (`settings-putaway`, 5.28).
- Button `settingsButton`. Items: How it works (`howItWorks`), What's new (`whatsNew`), the lists (section 3), "Save the shelf as a list" (0.5, see 5.9), 0.6 section "Your shelf": `settings-shelves` (5.14), `settings-kinds` (5.16), `settings-changes` (5.15); version line (`versionLine`, e.g. "AMS Reading Companion 0.3 (n)"), Done (`settingsDone`). Also `refresh-lists`, `import-kindle-file`, `import-file-note`, `lists-help`, `cloud-off`, `howItWorks` page `guidePage`, `whatsNew` page `newsPage`.

## 13. Data and safety
- The shelf is one file in the app's iCloud Drive folder, shared by Mac, iPhone, iPad.
- Own choices (status, wishes) merge per book; the newer change wins.
- A safety copy per device once a day, 14 days back.
- File format: `format` in the shelf file. 0.1 and 0.2 write 1; 0.3 writes 2 (adds per book `rating`, `note`, `gaveUp`; and a `series` table). A version that finds a higher format than it knows shows the shelf but changes nothing (read-only banner `newer-note`; no save, no import, no edit buttons). So a device on 0.2 meeting a format 2 file is read-only until updated. 0.3 reads format 1 files and raises them to 2 on its first change.
- 0.5 writes format 3. New data: per book `language`, `languageByHand`, `finished` (the finishing day); top level `upNext` (list of book ids) with `upNextChanged`, and `goals` (year → count) with `goalsChanged`; per series `byHand` (the total was typed by the owner). A device on 0.4 meeting a format 3 file is read-only until updated to 0.5. 0.5 reads older files and raises them to 3 on its first change. Merging: the Up next list and the goals each win whole by their own change time; the format of a merged file is the higher of the two.
- 0.6 writes format 4. New data: per book `tags`, `about`, `aboutChecked`, `detailsByHand`; top level `notes`, `noteKinds` with `noteKindsChanged`, `savedFilters`, `shelfOrder`, `hiddenShelves` with `shelvesChanged`, `changes`. A device on 0.5 meeting a format 4 file is read-only until updated to 0.6. 0.6 reads older files and raises them to 4 on its first change. Merging: notes and kept filters one by one by their `changed` (a removed one stays as a marker); the kinds list wins whole by `noteKindsChanged`; the order and the hidden shelves win whole by `shelvesChanged`; `changes` are put together by id (newest 40); a book's `about` and `aboutChecked` are carried across without being a change.
- 0.8 writes format 5 (was 4). New data: per book the put-away mark; per copy the stores' collections; per note "done"; top level the list of main-screen parts that are switched off. A device on 0.7 meeting a format 5 file is read-only until updated to 0.8.
- Fields it does not know in an entry make that entry skipped, not the whole file.
- Nothing about the owner's list is sent anywhere. What is sent is in 14.1. His notes, tags and kept shelves are never sent.

### 13.1 Shelf index and wishes for the Share extension
- Two files in the App Group `group.com.schabbauer.AMSReadingCompanion` (iPhone and iPad only): `shelf-index.json` (the app writes, for every shown book: title, author, store names, wish flag; refreshed when the app comes forward and after each save) and `pending-wishes.json` (the extension writes title, author; the app reads it when it comes forward, adds each as a wish and empties it).

## 14. Share check (iPhone and iPad only, extension "AMS Reading")
- Appears in the Share sheet for a web page, a web address or text (Safari). The extension reads the page's title, else the shared text, else the last words of the address.
- Matching (`ShareMatch.find`): the book title is cut out of the page title (`likelyTitle`); a shelf book matches only when its plain title key (no subtitle, accents, capitals, leading "The") EQUALS the key of that cut-out title, so "Dune" does not match a page about "Dune Messiah". Only when no title can be cut out, the fallback applies: the key's words appear in the page title in order, and a key with fewer than 5 letters needs the author's last name on the page too. Order: author found first, then longest title, then shelf order. With only a web address, the path parts book, books, dp, gp, product, ebook, en, se, us and any part with a digit are dropped.
- Matched: owned books under "You own this" (`share-owned`) with title, author and "in <stores>"; wishes under "Already on your wish list" (`share-wished`), never under "You own this". Then only Done (`share-done`). No index yet: "Open AMS Reading once on this device, then try again." (`share-no-index`).
- No match: "Not on your shelf" (`share-none`) with title (`share-title`) and author (`share-author`) guessed from the page title (Amazon, Apple Books and "Title by Author" forms; "Vale, Una" becomes "Una Vale"), both editable, a full-colour "Save to wish list" (`share-add-wish`) and a plain "Cancel" (`share-cancel`, adds nothing). The wish is queued in `pending-wishes.json` and lands on the shelf when the app is next opened. If the shared item has not arrived after 3 seconds, this state shows with empty fields.
- Not on the Mac. NOT yet tried on a real iPhone.

## 14.0 Home Screen widget "Reading" (0.5, iPhone and iPad only; `Widget/ReadingWidget.swift`)
- Small: the book being read now. Medium: up to 2 Reading-now books and one "What next?" suggestion with its reason.
- A tap opens that book's page (`amsreading://book/<id>`).
- Refresh: when the shelf changes, and at least every 6 hours (timeline policy). The widget fetches the covers itself; a book without a cover shows the same coloured title tile as the app. No data yet: "Open AMS Reading once to fill this."
- How the widget gets its books: the app writes a small snapshot (at most 3 Reading-now books and one suggestion: id, title, author, cover address) into the device's keychain, in the app's own keychain group `D24ENP83QQ.com.schabbauer.AMSReadingCompanion`; the widget is let into that group (`Widget/Widget.entitlements`) and reads it. Only written when it changed. Nothing leaves the device. (Not an App Group: a new one must be registered by hand at Apple; the keychain group needs no registration.)
- Not on the Mac.
- Not proven on a real device yet (17 Nov 2026): seen only as pictures of its views.

## 14.0.1 Device search (0.5, iPhone, iPad and Mac; `SpotlightIndex`)
- The books are put into the device's own search index (title, author). A result says "You own this · <stores>" (e.g. "Kobo, Kindle") or "On your wish list"; a tap opens that book's page.
- The index lives on the device only; nothing is sent anywhere.

## 14.1 Lookups in public catalogues (`ReadingCore/Lookups`)
All requests: 8 seconds time limit; an error or any doubt gives "nothing", never a failure on screen. Only title and author (or the barcode number) are sent; never the owner's list. Not run in `-sampleData`.
- Cover by title (`CoverLookup`): for a book with no cover address and no Apple Books number (Kindle books from a list file, books added by hand, wishes). Asks Apple Books (iTunes Search, Sweden, ebooks, 10 hits) first, then Open Library (search by title and author, needs a cover). Takes the first hit that is the same book (same title key; author last name equal or one unknown). Asked once per book and device (remembered in `coverTriedByTitle`); the answer is stored on the book, so every device gets it. Nothing fits: the coloured title tile stays. Apple Books books ask Apple by their own number (since 0.1).
- Series (`SeriesLookup`): Wikidata's public query service, one request per series. Finds a book the owner has by its title in English, Swedish or German and the author's last name (as written, with accents), follows "part of the series" and lists every book of that series by the same author with its number; volume titles come back in the language the title was found in, else English. A series whose name matches the one on the shelf (ignoring words like series, trilogy, saga, the) wins; when the catalogue files the book under exactly one series, that one is taken even under another name; a number given to two different books makes that series untrusted. A catalogue that could not be reached is not remembered as "unknown": the pass stops and tries again at the next start; a real answer (also "unknown") is kept 60 days. All answers of one pass are stored in one change. Real shelf, 17 Nov 2026: 3 of 11 series known (Fjällbacka 12, Millennium 3, Utvandrarserien 4); publishers' collections are not known. Limits: Wikidata does not know every series or number; then the app keeps "<n> owned". Asked once per series with 2 or more owned books, again after 60 days (also after an empty answer), at most 40 series per start, 0.4 s apart. Stored in the shelf file.
- Barcode (`ISBNLookup`): Open Library (`isbn:<number>`), then Apple Books (iTunes Lookup, 13 digits only, Sweden). Gives title, author, cover. Many books are known; some are not ("This number is not in the book catalogue.").
- Price (`PriceLookup`): Apple Books only (iTunes Search, Sweden). Kobo and Kindle give only search links.
- What a book is about (`AboutLookup`, 0.6): see 5.18. Title and author only.
- Library check (`LIBRIS`, 0.7): see 5.25. Title and the author's last name only (the app holds no ISBN for a wish; the lookup can take one). LIBRIS's open search (`xsearch`) gives no holdings: the app says in which forms Swedish libraries list the title, never which library. Asked when the wish's page opens; the answer is kept while the app is open; "could not reach" is never kept. Identifiers: `library-found`, `library-none`, `library-unreachable`, `library-open`. Other 0.7 identifiers: `finished-card`, `finished-save`, `finished-skip`, `quote-of-day`, `notes-search`, `notes-send-shown`, `notes-none-found`, `wall-toggle`, `cover-wall`, `book-pair`; shelf id `pairs` (colour olive).
- Catalogues named: Apple Books (itunes.apple.com), Open Library (openlibrary.org, covers.openlibrary.org), Wikidata (query.wikidata.org), Kobo (kobo.com, link only), Amazon (amazon.com, link only).

## 15. Launch arguments (pictures and screen tests)
- `-sampleData`: made-up books, nothing read, nothing saved, no lookups.
- `-search`, `-add`, `-scan`, `-settings`: open that sheet at start.
- `-show <title word>`: start on the page of the first book whose title begins with that word (a book id also works).
- `-shelf <id>`: start on that shelf's page (`reading`, `unread`, `aside`, `twice`, `gaveup`, `wish`, …).
- 0.6: `-filter` starts on the page "All books" (5.10); `-notes` the notebook; `-newnote` a new note for the book being read; `-page author|series|results|changes` starts on that page (author: the book being read, else the first owned; series: the first owned book that has one; results: the first kept filter); `-page shelves|kinds` with `-settings` opens Choose your shelves or Kinds of notes (the word is what is looked for among the arguments); `-show <word> -tags` and `-show <word> -correct` open the tags or the correction of that book.
- 0.8: `-authors` opens Your reading on Authors; `-settings -page putaway` opens the put-away page.
- Flag-only arguments (`-sampleData`, `-search`, `-add`, `-scan`, `-settings`, `-filter`, `-notes`, `-newnote`, `-tags`, `-correct`) must come last, after any argument that takes a value.

## 16. Look
- Hand-drawn icons, compact, colourful headings, full-colour main buttons, day and night.

## 17. Not proven yet
- Kobo list against the real Kobo library.
- Share check on a real iPhone.
- Camera scan on a real iPhone.
- The wide layout on a real iPad.
- Open buttons on iPhone (Apple Books, Kobo; and all opening on iPhone and iPad).
- Sending lock-free books (Open in Apple Books, Send to Kobo, Send to Kindle) end to end.
- 0.6, on a real device: Speak (microphone and speech), Photo of the page (camera; on the Mac a picture file), sharing a note to another app (for example PARAGON), the description lookup on the owner's real books.

- 0.7, on a real device: the library check on the owner's real wish list, the cover wall on an iPad.
- 0.8, on a real device: the collections from the owner's real Apple Books and Kobo; joining two real books. Still open from 0.7: the library check on a real wish, the cover wall on an iPad.

## 18. Later
- Highlights.
- Sending from iPhone.
- Lock-free marks for store books.
- Kobo and Kindle prices (the stores do not let an app read them).

## 19. Version history
- 0.1 (17 Nov 2026): first version.
- 0.2 (17 Nov 2026): fix. Built-in Kindle entries left out (16 entries became 2); samples and built-in items marked later leave the shelf; honest Kindle count in Settings.
- 0.3 (17 Nov 2026): What next? card; shelves Set aside (72 started books leave Not read yet), Bought twice (7), Gave up; own stars and note; Next in the series; series note "3 of 7" from a public catalogue; covers by title and author; sort and filter on a shelf page; Share check and barcode scan (iPhone and iPad); wish-list prices; Kindle list from Amazon's page saved as PDF; no second copy of a store from a repeated list file; file format 2.
- 0.6 (18 Nov 2026): the big filter (funnel button opens the page "All books" with menus above the books: Store, Kind, Language, Status, More = Your stars, Bought, Finished, Tags, Lock-free; ticks, books change at once, Clear, Keep); filters kept as shelves of his own; author's page and series' page (missing part to the wish list); his own tags (book page, search, filter); Choose your shelves (show, hide, order); Surprise me on What next?; progress bar on covers and "n % read"; correct title, author, series of a book; what a book is about (Apple Books, Open Library); What changed (last 40 reads of the stores' lists); reading notes (kinds of his own; Type, Speak, Photo of the page; notebook; Share a note, send all notes of a book as one page); file format 4 (a device on 0.5 is read-only).
- 0.7 (18 Nov 2026): search in the notebook; quote of the day; "Just finished" card (stars and a few words); "Send these" in the notebook; shelf Read + listen; cover wall; library check (LIBRIS) on a wish-list book; the tour now covers 0.4 to 0.7. The shelf file stays at format 4; nothing new is stored in it.
- 0.8 (18 Nov 2026): shelves New on the shelf and Waiting longest; Authors as third part of Your reading; the stores' collections (Apple Books, Kobo) as tags; Put away; Join two books; Select several books (Tag, Status, Up next, Put away); Main screen and shelves (five switches); To do tick boxes; library check on a series' page. Shelf file format 5.
- Look picks (18 Nov 2026): the owner chose look 2 "menus above the books" for the big filter and look 4 "one notebook" (the pen at the right end of the "Reading notes" line, not in the top bar) from one numbered picture.
- 0.5 (17 Nov 2026): Up next list (button on the book page, shelf under Reading now, Change order, first in What next?); Your reading (Year with goals and finishing days, Numbers); language of every book with a careful title guess, set by hand, filter on a shelf page; Home Screen widget "Reading" (iPhone, iPad); device search finds the books; own EPUB folders packed into one .epub when sent from the Mac; series length by hand; Save the shelf as a list (PDF, Table); file format 3 (a device on 0.4 is read-only); the app's code is public on GitHub with automatic tests on every change (no real titles; sample and tests use made-up books).
- 0.4 (17 Nov 2026): wide layout on iPad and Mac (window 760 points or more): shelves on the left, the chosen book's page on the right (38 % of the width, 340 to 440 points); narrow windows and iPhone unchanged; identifiers `book-pane`, `book-pane-empty`; no data change.
