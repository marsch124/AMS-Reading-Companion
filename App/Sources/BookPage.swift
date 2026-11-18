import AMSIcons
import ReadingCore
import SwiftUI

/// One book: cover, stores, reading status, Open per copy, sending for lock-free books, Remove.
struct BookPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var askRemove = false
    @State private var editingNote = false
    @State private var price: PriceFound?
    @State private var priceAsked = false
    @State private var wishedNext = false
    @State private var editingDay = false
    // For pictures: `-correct` and `-tags` start with that page open (with `-show <title word>`).
    @State private var correcting = ProcessInfo.processInfo.arguments.contains("-correct")
    @State private var tagging = ProcessInfo.processInfo.arguments.contains("-tags")
    @State private var noteDraft: NoteDraft?
    @State private var aboutOpen = false
    @Environment(\.openRoute) private var openRoute

    private let colour = "purple"

    var body: some View {
        Group {
            if let book = model.data.book(bookID) {
                content(book)
            } else {
                Text("This book is no longer on the shelf.")
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .accessibilityIdentifier("book-page")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { model.trouble = nil; model.notice = nil }
    }

    private func content(_ book: Book) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(book)
                statusRow(book)
                if book.status == .reading || book.gaveUp { gaveUpRow(book) }
                if model.data.canBeUpNext(book) { upNextRow(book) }
                if book.status == .finished { finishedRow(book) }
                if !book.wish { languageRow(book) }
                starsAndNote(book)
                tagsRow(book)
                readingNotes(book)
                if let about = book.about { aboutPart(about) }
                if let next = model.data.nextInSeries(after: book) { nextRow(next, after: book) }
                if book.wish { buying(book) }
                if !book.copies.isEmpty { copies(book) }
                if book.isLockFree { sending(book) }
                if let trouble = model.trouble {
                    Text(trouble)
                        .font(.callout)
                        .foregroundStyle(Theme.text("red"))
                        .accessibilityIdentifier("book-trouble")
                }
                if let notice = model.notice {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("book-notice")
                }
                if !model.readOnly {
                    Button { correcting = true } label: {
                        Text(book.detailsByHand ? "Correct title, author or series (corrected by you)" : "Correct title, author or series")
                            .foregroundStyle(Theme.text(colour))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("book-correct")
                }
                if model.data.canRemove(book) && !model.readOnly {
                    Button { askRemove = true } label: {
                        Text("Remove from shelf")
                            .foregroundStyle(Theme.text("red"))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("book-remove")
                    .confirmationDialog("Remove “\(book.title)” from the shelf?", isPresented: $askRemove,
                                        titleVisibility: .visible) {
                        Button("Remove", role: .destructive) {
                            model.remove(book.id)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $correcting) { CorrectBookPage(bookID: book.id) }
        .sheet(isPresented: $tagging) { TagsPage(bookID: book.id) }
        .sheet(item: $noteDraft) { NoteEditPage(draft: $0) }
        .task(id: book.id) { model.lookUpAbout(book) }
    }

    private func header(_ book: Book) -> some View {
        HStack(alignment: .top, spacing: 14) {
            CoverView(book: book, width: 110)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("book-title")
                if !book.author.isEmpty {
                    // The author's name leads to every book of theirs, owned and wished.
                    if let openRoute {
                        Button { openRoute(.author(book.author)) } label: {
                            Text(book.author)
                                .foregroundStyle(Theme.text("indigo"))
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-author")
                    } else {
                        Text(book.author).foregroundStyle(.secondary)
                    }
                }
                if let line = seriesLine(book) {
                    // The series' name leads to every part of it: owned, read, missing.
                    if let openRoute, let series = book.series {
                        Button { openRoute(.series(series)) } label: {
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(Theme.text("green"))
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-series")
                    } else {
                        Text(line).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                StoreMarks(book: book)
                if let done = LibraryData.coverProgress(book) {
                    Text("\(Int((done * 100).rounded())) % read")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("book-progress")
                }
                if book.ownedTwice {
                    Text("Owned twice")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text("red"))
                }
                if book.wish {
                    Text("On your wish list")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text("blue"))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func seriesLine(_ book: Book) -> String? {
        guard let series = book.series, !series.isEmpty else { return nil }
        guard let n = book.seriesNumber, n.isFinite, abs(n) < 1_000_000 else { return series }
        let number = n == n.rounded() ? String(Int(n)) : String(n)
        return "\(series) · book \(number)"
    }

    private func statusRow(_ book: Book) -> some View {
        let choices: [(ReadStatus, String)] = [(.unread, "Not read"), (.reading, "Reading"), (.finished, "Finished")]
        return HStack(spacing: 6) {
            ForEach(choices, id: \.0) { status, label in
                let chosen = book.status == status
                Button { model.setStatus(status, of: book.id) } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(chosen ? Color.white : Theme.text(colour))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(chosen ? Theme.fill(colour) : Theme.fill(colour).opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(model.readOnly)
                .accessibilityIdentifier("status-\(status.rawValue)")
            }
        }
    }

    // MARK: Gave up

    private func gaveUpRow(_ book: Book) -> some View {
        HStack(spacing: 10) {
            if book.gaveUp {
                Text("You gave this one up.")
                    .foregroundStyle(Color.secondary)
                Button("Pick it up again") { model.setGaveUp(false, of: book.id) }
                    .accessibilityIdentifier("book-pick-up")
            } else {
                Button("Gave up on it") { model.setGaveUp(true, of: book.id) }
                    .accessibilityIdentifier("book-gave-up")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.text("brown"))
        .buttonStyle(.plain)
        .disabled(model.readOnly)
    }

    // MARK: Up next, finishing day, language

    private func upNextRow(_ book: Book) -> some View {
        let place = model.data.upNextBooks.firstIndex { $0.id == book.id }
        return HStack(spacing: 10) {
            if let place {
                Text("Number \(place + 1) on your Up next list.")
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("book-upnext-place")
                Button("Take off Up next") { model.removeUpNext(book.id) }
                    .accessibilityIdentifier("book-upnext-off")
            } else {
                Button("Add to Up next") { model.addUpNext(book.id) }
                    .accessibilityIdentifier("book-upnext-add")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.text("indigo"))
        .buttonStyle(.plain)
        .disabled(model.readOnly)
    }

    private func finishedRow(_ book: Book) -> some View {
        HStack(spacing: 10) {
            if let day = book.finishedDay {
                Text("Finished \(day.formatted(.dateTime.day().month(.abbreviated).year())).")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("book-finished-day")
            } else {
                Text("Finishing day not known.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("book-finished-day")
            }
            if !model.readOnly {
                Button(book.finishedDay == nil ? "Set the day" : "Change") { editingDay = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text(colour))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("book-finished-change")
            }
        }
        .font(.footnote)
        .sheet(isPresented: $editingDay) {
            FinishedDayPage(bookID: book.id, day: book.finishedDay ?? Date())
        }
    }

    /// The language a store told or the title gave away. The menu sets it by hand; that choice stays.
    private func languageRow(_ book: Book) -> some View {
        var codes = ["sv", "en", "de"]
        for found in LibraryData.languages(in: model.data.owned) where !codes.contains(found.code) { codes.append(found.code) }
        return HStack(spacing: 6) {
            Text("Language")
                .foregroundStyle(.secondary)
            if model.readOnly {
                Text(book.language.map(BookLanguage.name) ?? "Not known")
            } else {
                Menu {
                    ForEach(codes, id: \.self) { code in
                        Button(BookLanguage.name(code)) { model.setLanguage(code, of: book.id) }
                    }
                    Button("Not known") { model.setLanguage(nil, of: book.id) }
                } label: {
                    Text(book.language.map(BookLanguage.name) ?? "Not known")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text("blue"))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityIdentifier("book-language")
            }
        }
        .font(.footnote)
    }

    // MARK: Stars and note

    private func starsAndNote(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your stars and note")
                    .font(.headline)
                    .foregroundStyle(Theme.text("amber"))
                Spacer(minLength: 8)
                if !model.readOnly {
                    Button("Edit") { editingNote = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text("amber"))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-note-edit")
                }
            }
            StarsView(rating: book.rating ?? 0, size: 20)
                .accessibilityIdentifier("book-stars")
            if let note = book.note {
                Text(note)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("book-note")
            } else {
                Text("No note yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $editingNote) {
            NotePage(bookID: book.id, stars: book.rating ?? 0, text: book.note ?? "")
        }
    }

    // MARK: Tags, reading notes, what it is about (0.6)

    private func tagsRow(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tags")
                    .font(.headline)
                    .foregroundStyle(Theme.text("teal"))
                Spacer(minLength: 8)
                if !model.readOnly {
                    Button(book.tags.isEmpty ? "Add" : "Edit") { tagging = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text("teal"))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-tags-edit")
                }
            }
            if book.tags.isEmpty {
                Text("No tags yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                // A tap on a tag shows every book that carries it.
                ChipFlow {
                    ForEach(book.tags, id: \.self) { tag in
                        Chip(title: tag, colour: "teal", on: false) {
                            var filter = BookFilter()
                            filter.tags = [LibraryData.tagKey(tag)]
                            openRoute?(.results(filter))
                        }
                        .accessibilityIdentifier("book-tag-\(LibraryData.tagKey(tag))")
                    }
                }
            }
        }
    }

    private func readingNotes(_ book: Book) -> some View {
        let notes = model.data.notes(of: book.id)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(notes.isEmpty ? "Reading notes" : "Reading notes · \(notes.count)")
                    .font(.headline)
                    .foregroundStyle(Theme.text("orange"))
                Spacer(minLength: 8)
                if !model.readOnly {
                    Button("New note") { noteDraft = NoteDraft(bookID: book.id) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text("orange"))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-new-note")
                }
            }
            if notes.isEmpty {
                Text("Nothing noted yet. Type, speak, or take a photo of the page.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    Button { noteDraft = NoteDraft(bookID: book.id, noteID: note.id) } label: {
                        NoteRow(note: note)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.readOnly)
                    .accessibilityIdentifier("book-note-\(note.id)")
                }
                // All notes of this book as one tidy page, to any app that takes words.
                ShareLink(item: model.data.notesPage(of: book.id),
                          subject: Text("Notes on “\(book.title)”")) {
                    Text(notes.count == 1 ? "Send this note as a page" : "Send all \(notes.count) notes as one page")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text("orange"))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityIdentifier("book-notes-send")
            }
        }
    }

    private func aboutPart(_ about: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("What it is about")
                .font(.headline)
                .foregroundStyle(Theme.text("brown"))
            Text(about)
                .lineLimit(aboutOpen ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("book-about")
            if about.count > 260 {
                Button(aboutOpen ? "Less" : "More") { aboutOpen.toggle() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text("brown"))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("book-about-more")
            }
            Text("From the publisher, as a catalogue lists it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Next in the series

    private func nextRow(_ next: SeriesNext, after book: Book) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Next in the series")
                .font(.headline)
                .foregroundStyle(Theme.text("green"))
            if let have = next.owned {
                BookLink(id: have.id, pushes: true) {
                    HStack(spacing: 8) {
                        CoverView(book: have, width: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Book \(next.number): \(have.title)")
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text("On your shelf · \(statusWord(have.status))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("next-owned")
            } else {
                Text(next.title.map { "Book \(next.number): \($0)" } ?? "Book \(next.number)")
                    .accessibilityIdentifier("next-missing")
                if wishedNext {
                    Text("Added to your wish list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not on your shelf.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let title = next.title, !model.readOnly {
                        Button("Add to wish list") {
                            model.add(title: title, author: book.author, store: nil)
                            wishedNext = true
                        }
                        .buttonStyle(FilledButton(colour: "green"))
                        .accessibilityIdentifier("next-add-wish")
                    }
                }
            }
        }
    }

    private func statusWord(_ status: ReadStatus) -> String {
        switch status {
        case .unread: return "not read"
        case .reading: return "reading"
        case .finished: return "finished"
        }
    }

    // MARK: Where to buy (a wish)

    private func buying(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Where to buy")
                .font(.headline)
                .foregroundStyle(Theme.text("blue"))
            if let price, let address = URL(string: price.url) {
                Link("Apple Books · \(price.price)", destination: address)
                    .accessibilityIdentifier("price-apple")
            } else {
                Text(priceAsked ? "Apple Books shows no price for this title in Sweden." : "Asking Apple Books for the price…")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("price-apple-none")
            }
            if let kobo = PriceLookup.koboSearch(title: book.title, author: book.author) {
                Link("Look on Kobo", destination: kobo)
                    .accessibilityIdentifier("price-kobo")
            }
            if let kindle = PriceLookup.kindleSearch(title: book.title, author: book.author) {
                Link("Look on Kindle", destination: kindle)
                    .accessibilityIdentifier("price-kindle")
            }
            Text("Kobo and Kindle do not let an app read their prices, so these two open their search pages in your browser.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Theme.text("blue"))
        .task(id: book.id) {
            guard !model.sample else {
                priceAsked = true
                return
            }
            price = await PriceLookup.apple(title: book.title, author: book.author, country: "se")
            priceAsked = true
        }
    }

    private func kindName(_ kind: BookKind) -> String {
        switch kind {
        case .ebook: return "ebook"
        case .audiobook: return "audiobook"
        case .pdf: return "PDF"
        }
    }

    private func copies(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(book.copies) { copy in
                HStack(spacing: 8) {
                    Circle().fill(Theme.store(copy.store)).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(copy.store.name) · \(kindName(copy.kind))")
                        if let date = copy.purchased {
                            Text("bought \(date.formatted(.dateTime.day().month(.abbreviated).year()))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if canOpen(copy) {
                        Button { model.open(copy, of: book) } label: {
                            HStack(spacing: 5) {
                                AppMarkView(.openApp, size: 18)
                                Text("Open")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.fill(colour), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-\(copy.store.rawValue)")
                    }
                }
            }
        }
    }

    private func canOpen(_ copy: BookCopy) -> Bool {
        if copy.source == .hand { return false }
        if copy.store == .own { return copy.source == .apple }
        return true
    }

    @ViewBuilder
    private func sending(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Send")
                .font(.headline)
                .foregroundStyle(Theme.text(colour))
            if !book.copies.contains(where: { $0.lockFree && $0.filePath != nil }) {
                Text("This book was added by hand, so there is no file here to send.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("send-no-file")
            } else if model.canSend {
                HStack(spacing: 8) {
                    sendButton("Open in Apple Books", .apple, book)
                    sendButton("Send to Kobo", .kobo, book)
                    sendButton("Send to Kindle", .kindle, book)
                }
            } else {
                Text("Sending is done on the Mac.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("send-mac-only")
            }
        }
    }

    private func sendButton(_ title: String, _ target: SendTarget, _ book: Book) -> some View {
        Button { model.send(book, to: target) } label: {
            HStack(spacing: 5) {
                AppMarkView(.send, size: 18)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(FilledButton(colour: colour))
        .disabled(model.readOnly)
        .accessibilityIdentifier("send-\(target.rawValue)")
    }
}

/// The owner's stars and note for one book. A page that changes something: Cancel and Save.
struct NotePage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State var stars: Int
    @State var text: String

    private let colour = "amber"

    var body: some View {
        NavigationStack {
            Form {
                Section("Stars") {
                    StarsView(rating: stars, size: 30) { stars = $0 }
                        .padding(.vertical, 2)
                    Text(stars == 0 ? "No stars. Tap a star to rate." : "Tap the last filled star to take one away.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Your note") {
                    TextField("One line about this book", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("stars-note-text")
                }
            }
            .navigationTitle("Stars and note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("stars-note-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setRating(stars == 0 ? nil : stars, of: bookID)
                        model.setNote(text, of: bookID)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("stars-note-save")
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 380)
        #endif
    }
}
