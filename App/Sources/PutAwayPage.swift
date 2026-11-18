import ReadingCore
import SwiftUI

/// "Put away": the books taken off every shelf, each with a button to take it out again.
struct PutAwayPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss

    private let colour = "purple"

    var body: some View {
        NavigationStack {
            List {
                Text("Books you put away stand on no shelf and in no count. The search still finds them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(model.data.putAwayBooks) { book in
                    HStack(spacing: 10) {
                        CoverView(book: book, width: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(book.title).lineLimit(2)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 6)
                        if !model.readOnly {
                            Button("Take out again") { model.setPutAway(false, of: [book.id]) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text(colour))
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("putaway-out-\(book.id)")
                        }
                    }
                }
            }
            .navigationTitle("Put away")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(colour: colour))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("putaway-done")
                }
            }
        }
        .accessibilityIdentifier("putaway-page")
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }
}
