import AMSIcons
import ReadingCore
import SwiftUI

/// One book: cover, stores, reading status, Open per copy, sending for lock-free books, Remove.
struct BookPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var askRemove = false

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
                    Text(book.author).foregroundStyle(.secondary)
                }
                if let line = seriesLine(book) {
                    Text(line).font(.footnote).foregroundStyle(.secondary)
                }
                StoreMarks(book: book)
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
        guard let n = book.seriesNumber else { return series }
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
