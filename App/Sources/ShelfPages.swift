import AMSIcons
import ReadingCore
import SwiftUI

// Two pages of the main screen's shelves: which shelves show and in what order, and what changed in the stores.

/// "Choose your shelves": tick, hide and move the shelves of the main screen.
struct ShelvesChoicePage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ShelfChoice] = []
    @State private var loaded = false

    private let colour = "purple"

    var body: some View {
        NavigationStack {
            List {
                Text("Ticked shelves show on the main screen, in this order. A hidden shelf keeps its books.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(Array(rows.enumerated()), id: \.element.key) { place, row in
                    line(row, place: place)
                }
                Button("Back to the usual order") { resetRows() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text(colour))
                    .buttonStyle(.plain)
                    .disabled(model.readOnly)
                    .accessibilityIdentifier("shelves-reset")
            }
            .navigationTitle("Choose your shelves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if model.readOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .keyboardShortcut(.cancelAction)
                            .accessibilityIdentifier("shelves-cancel")
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .keyboardShortcut(.cancelAction)
                            .accessibilityIdentifier("shelves-cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if usual {
                                model.setShelves(order: [], hidden: [])
                            } else {
                                model.setShelves(order: rows.map(\.key), hidden: rows.filter(\.hidden).map(\.key))
                            }
                            dismiss()
                        }
                        .buttonStyle(FilledButton(colour: colour))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("shelves-save")
                    }
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            rows = model.data.shelfChoices()
        }
        .accessibilityIdentifier("shelves-page")
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    /// Set when "Back to the usual order" was pressed and nothing was changed since.
    @State private var usual = false

    private func line(_ row: ShelfChoice, place: Int) -> some View {
        HStack(spacing: 10) {
            Button { toggle(place) } label: {
                ControlMarkView(row.hidden ? .circle : .ticked, size: 20,
                                colour: row.hidden ? nil : Theme.text(colour))
            }
            .disabled(model.readOnly)
            .accessibilityLabel(row.hidden ? "Show" : "Hide")
            .accessibilityIdentifier("shelves-tick-\(row.key)")
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .foregroundStyle(row.hidden ? Color.secondary : Color.primary)
                    .lineLimit(2)
                Text(countText(row))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if !model.readOnly {
                Button { move(place, by: -1) } label: {
                    AppMarkView(.arrowUp, size: 20, colour: Theme.text(colour))
                }
                .disabled(place == 0)
                .opacity(place == 0 ? 0.3 : 1)
                .accessibilityLabel("Move up")
                .accessibilityIdentifier("shelves-up-\(place)")
                Button { move(place, by: 1) } label: {
                    AppMarkView(.arrowUp, size: 20, colour: Theme.text(colour))
                        .rotationEffect(.degrees(180))
                }
                .disabled(place == rows.count - 1)
                .opacity(place == rows.count - 1 ? 0.3 : 1)
                .accessibilityLabel("Move down")
                .accessibilityIdentifier("shelves-down-\(place)")
            }
        }
        .buttonStyle(.plain)
    }

    private func countText(_ row: ShelfChoice) -> String {
        if row.count == 0 { return "empty now" }
        if row.key == "series" { return "\(row.count) series" }
        return row.count == 1 ? "1 book" : "\(row.count) books"
    }

    private func toggle(_ place: Int) {
        guard rows.indices.contains(place) else { return }
        rows[place].hidden.toggle()
        usual = false
    }

    private func move(_ place: Int, by step: Int) {
        let to = place + step
        guard rows.indices.contains(place), rows.indices.contains(to) else { return }
        rows.swapAt(place, to)
        usual = false
    }

    private func resetRows() {
        var d = model.data
        d.setShelves(order: [], hidden: [])
        rows = d.shelfChoices()
        usual = true
    }
}

/// "What changed": the books that came and left at each read of a store.
struct ChangesPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss

    private let colour = "green"

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                if model.data.changes.isEmpty {
                    Text("Nothing has come or left yet. Each time the Mac reads a store's list, the books that are new and the ones that are gone are noted here.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("changes-empty")
                }
                ForEach(Array(model.data.changes.enumerated()), id: \.element.id) { index, entry in
                    entryView(entry)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("changes-entry-\(index)")
                }
            }
            .navigationTitle("What changed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(colour: colour))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("changes-done")
                }
            }
        }
        .accessibilityIdentifier("changes-page")
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    @ViewBuilder
    private func entryView(_ entry: ChangeEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(entry.storeName) · \(Self.dayFormat.string(from: entry.date))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text(colour))
            ForEach(Array(entry.came.enumerated()), id: \.offset) { _, title in
                line(title, plus: true)
            }
            if entry.cameCount > entry.came.count {
                more("and \(entry.cameCount - entry.came.count) more came")
            }
            ForEach(Array(entry.left.enumerated()), id: \.offset) { _, title in
                line(title, plus: false)
            }
            if entry.leftCount > entry.left.count {
                more("and \(entry.leftCount - entry.left.count) more left")
            }
        }
    }

    private func line(_ title: String, plus: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Group {
                if plus {
                    ControlMarkView(.add, size: 14, colour: Theme.text(colour))
                } else {
                    AppMarkView(.minus, size: 14, colour: Theme.text("red"))
                }
            }
            .frame(width: 14)
            Text(title).font(.callout).lineLimit(2)
        }
    }

    private func more(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary).padding(.leading, 20)
    }
}
