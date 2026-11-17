import AMSIcons
import ReadingCore
import SwiftUI

// The small pages of version 0.5 that change something. Each has Cancel and Save; on the Mac, Escape is Cancel.

/// The Up next list: move a book up or down, or take it off.
struct UpNextOrderPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var ids: [String] = []
    @State private var loaded = false

    private let colour = "indigo"

    var body: some View {
        NavigationStack {
            List {
                if ids.isEmpty {
                    Text("Nothing on the list. On a book you have not started, tap “Add to Up next”.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("upnext-empty")
                }
                ForEach(Array(ids.enumerated()), id: \.element) { place, id in
                    if let book = model.data.book(id) {
                        row(book, place: place)
                    }
                }
            }
            .navigationTitle("Up next")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("upnext-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setUpNext(ids)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("upnext-save")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            ids = model.data.upNextBooks.map(\.id)
        }
        .accessibilityIdentifier("upnext-order-page")
        #if os(macOS)
        .frame(width: 460, height: 460)
        #endif
    }

    private func row(_ book: Book, place: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(place + 1)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text(colour))
                .frame(width: 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(book.title).lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Button { move(place, by: -1) } label: {
                AppMarkView(.arrowUp, size: 20, colour: Theme.text(colour))
            }
            .disabled(place == 0)
            .opacity(place == 0 ? 0.3 : 1)
            .accessibilityLabel("Move up")
            .accessibilityIdentifier("upnext-up-\(place)")
            Button { move(place, by: 1) } label: {
                AppMarkView(.arrowUp, size: 20, colour: Theme.text(colour))
                    .rotationEffect(.degrees(180))
            }
            .disabled(place == ids.count - 1)
            .opacity(place == ids.count - 1 ? 0.3 : 1)
            .accessibilityLabel("Move down")
            .accessibilityIdentifier("upnext-down-\(place)")
            Button { ids.remove(at: place) } label: {
                ControlMarkView(.minusCircle, size: 20, colour: Theme.text("red"))
            }
            .accessibilityLabel("Take off the list")
            .accessibilityIdentifier("upnext-off-\(place)")
        }
        .buttonStyle(.plain)
    }

    private func move(_ place: Int, by step: Int) {
        let to = place + step
        guard ids.indices.contains(place), ids.indices.contains(to) else { return }
        ids.swapAt(place, to)
    }
}

/// How many books a series has, typed by the owner.
struct SeriesLengthPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State private var text = ""
    @State private var loaded = false

    private let colour = "green"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Number of books", text: $text)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("series-length-field")
                } header: {
                    Text("How many books has “\(name)”?")
                } footer: {
                    Text("The shelf then shows which ones you are missing. Your number stays, whatever a catalogue says. Leave it empty to take your number away.")
                }
            }
            .navigationTitle("Series length")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("series-length-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setSeriesTotal(Int(text.trimmingCharacters(in: .whitespaces)), for: name)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("series-length-save")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let total = model.data.seriesInfo(for: name)?.total { text = String(total) }
        }
        .presentationDetents([.height(300)])
        #if os(macOS)
        .frame(width: 420, height: 260)
        #endif
    }
}

/// The day a book was finished, corrected by the owner.
struct FinishedDayPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State var day: Date

    private let colour = "purple"

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Finished on", selection: $day, in: ...Date(), displayedComponents: .date)
                    .accessibilityIdentifier("finished-day-picker")
            }
            .navigationTitle("Finishing day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("finished-day-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setFinishedDay(day, of: bookID)
                        dismiss()
                    }
                    .buttonStyle(FilledButton(colour: colour))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("finished-day-save")
                }
            }
        }
        .presentationDetents([.height(240)])
        #if os(macOS)
        .frame(width: 400, height: 200)
        #endif
    }
}
