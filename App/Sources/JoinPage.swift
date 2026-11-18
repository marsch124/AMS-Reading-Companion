import AMSIcons
import ReadingCore
import SwiftUI

/// Choose the other book that is the same as this one, then join them. A page that changes something: Cancel and Join.
struct JoinPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var text = ""
    @State private var chosen: String?
    @State private var asking = false

    private let colour = "purple"

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var choices: [Book] {
        let all = model.data.joinChoices(for: bookID)
        let words = fold(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.isEmpty { return Array(all.prefix(30)) }
        return all.filter { book in
            let hay = fold([book.title, book.author, book.series ?? ""].joined(separator: " "))
            return words.allSatisfy { hay.contains($0) }
        }
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private var chosenBook: Book? { chosen.flatMap { model.data.book($0) } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("When the app took one book for two, choose the other one here. Its copies, notes and tags move to this book, and the other one leaves the shelf. This cannot be taken apart again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                field
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(choices) { book in row(book) }
                        if choices.isEmpty {
                            Text("No other book matches.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("join-none")
                        } else if query.isEmpty {
                            Text("Type to look for others.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Same book as…")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("join-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") { asking = true }
                        .buttonStyle(FilledButton(colour: colour))
                        .disabled(chosenBook == nil)
                        .accessibilityIdentifier("join-save")
                }
            }
            .confirmationDialog(askTitle, isPresented: $asking, titleVisibility: .visible) {
                Button("Join", role: .destructive) {
                    if let chosen { model.join(chosen, into: bookID) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .accessibilityIdentifier("join-page")
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    private var askTitle: String {
        let mine = model.data.book(bookID)?.title ?? ""
        return "Join “\(chosenBook?.title ?? "")” into “\(mine)”? This cannot be undone."
    }

    private var field: some View {
        HStack(spacing: 8) {
            AppMarkView(.search, size: 18)
                .foregroundStyle(Theme.text(colour))
            TextField("Title, author or series", text: $text)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("join-search")
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ book: Book) -> some View {
        let on = chosen == book.id
        return Button { chosen = book.id } label: {
            HStack(spacing: 10) {
                CoverView(book: book, width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.body.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    if !book.author.isEmpty {
                        Text(book.author).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    StoreMarks(book: book)
                }
                Spacer(minLength: 0)
                if on {
                    Circle().fill(Theme.fill(colour)).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2).frame(width: 6, height: 6).opacity(0))
                } else {
                    Circle().stroke(Theme.text(colour).opacity(0.45), lineWidth: 1.5).frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(on ? Theme.fill(colour).opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Theme.fill(colour) : Color.clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("join-row-\(book.id)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
