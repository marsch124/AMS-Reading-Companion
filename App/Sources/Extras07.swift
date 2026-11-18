import SwiftUI
import ReadingCore

// Version 0.7 on the screens: the quote of the day, the "Just finished" card and the library check.

extension ReadingModel {
    private static let skippedKey = "finishedSkipped"

    /// The finished books the owner answered "Not now" for. Kept on this device only.
    var finishedSkipped: Set<String> {
        sample ? Self.sampleSkipped : Set(UserDefaults.standard.stringArray(forKey: Self.skippedKey) ?? [])
    }
    /// With the made-up books nothing is kept: "Not now" lasts until the app closes.
    private static var sampleSkipped: Set<String> = []

    /// The book to ask "how was it?" about, if any.
    var justFinished: Book? {
        guard !readOnly else { return nil }
        // For pictures: `-finished` asks about the first finished book without stars, whenever it was finished.
        if sample, ProcessInfo.processInfo.arguments.contains("-finished") {
            return data.owned.first { $0.status == .finished && $0.rating == nil && !finishedSkipped.contains($0.id) }
        }
        guard !sample else { return nil }
        return data.justFinished(skipped: finishedSkipped)
    }

    func skipFinished(_ id: String) {
        objectWillChange.send()
        if sample { Self.sampleSkipped.insert(id); return }
        var all = UserDefaults.standard.stringArray(forKey: Self.skippedKey) ?? []
        if !all.contains(id) { all.append(id) }
        UserDefaults.standard.set(Array(all.suffix(200)), forKey: Self.skippedKey)
    }
}

/// On top of the main screen when a book was finished in the last two weeks and has no stars yet.
struct FinishedCard: View {
    @EnvironmentObject private var model: ReadingModel
    let book: Book
    @State private var stars = 0
    @State private var text = ""

    private let colour = "amber"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                BookLink(id: book.id) { CoverView(book: book, width: 44) }
                    .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Just finished")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.text(colour))
                    Text(book.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                    StarsView(rating: stars, size: 26) { stars = $0 }
                        .padding(.top, 1)
                }
                Spacer(minLength: 0)
            }
            TextField("How was it? One line", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("finished-text")
            HStack(spacing: 14) {
                Spacer(minLength: 0)
                Button("Not now") { model.skipFinished(book.id) }
                    .buttonStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text(colour))
                    .accessibilityIdentifier("finished-skip")
                Button("Save") {
                    let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !words.isEmpty { model.setNote(words, of: book.id) }
                    if stars > 0 { model.setRating(stars, of: book.id) } else { model.skipFinished(book.id) }
                }
                .buttonStyle(FilledButton(colour: colour))
                .accessibilityIdentifier("finished-save")
            }
        }
        .padding(10)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finished-card")
        .onAppear { text = book.note ?? "" }
    }
}

/// One of the owner's own quotes, another one each day. A tap opens the note.
struct QuoteLine: View {
    @EnvironmentObject private var model: ReadingModel
    let note: ReadingNote

    var body: some View {
        let book = model.data.book(note.bookID)
        Button { model.noteDraft = NoteDraft(bookID: note.bookID, noteID: note.id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text("“\(note.text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”„«»").union(.whitespacesAndNewlines)))”")
                    .font(.subheadline.italic())
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Text(["Quote of the day", book?.title].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.readOnly)
        .padding(.horizontal, 12)
        .accessibilityIdentifier("quote-of-day")
    }
}

/// On a wish's page: does Sweden's library catalogue list the title, and in which forms?
struct LibraryCheck: View {
    @EnvironmentObject private var model: ReadingModel
    let book: Book
    @State private var answer: LibraryAnswer?

    /// What was found before, kept while the app is open, so a page opened again does not ask again.
    @MainActor private static var known: [String: LibraryAnswer] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("At the library?")
                .font(.headline)
                .foregroundStyle(Theme.text("green"))
            switch answer {
            case nil:
                Text("Asking Sweden's library catalogue…").foregroundStyle(.secondary)
            case .found(let finding):
                Text("Swedish libraries list it as: \(finding.forms.map(\.name).joined(separator: ", ").lowercased()).")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("library-found")
            case .unknown:
                Text("Sweden's library catalogue does not list this title.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("library-none")
            case .unreachable:
                Text("The library catalogue could not be reached just now.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("library-unreachable")
            }
            if let page = LibraryLookup.page(title: book.title, author: book.author) {
                Link("Open at the library", destination: page)
                    .accessibilityIdentifier("library-open")
            }
            Text("This is the national catalogue (LIBRIS). It tells that libraries in Sweden have the title, not which one; its page lists the libraries.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Theme.text("green"))
        .task(id: book.id) {
            if let before = Self.known[book.id] { answer = before; return }
            guard !model.sample else {
                answer = .found(LibraryFinding(forms: [.book, .ebook], link: "", checked: Date()))
                return
            }
            let found = await LibraryLookup.look(title: book.title, author: book.author, isbn: nil)
            answer = found
            if found != .unreachable { Self.known[book.id] = found }
        }
    }
}
