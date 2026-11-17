import ReadingCore
import SwiftUI

/// "Your reading": the year in books with a yearly goal, and the shelf counted.
struct YearPage: View {
    enum Part: Hashable { case year, numbers }

    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var part: Part
    @State private var goalYear: Int?

    init(start: Part = .year) { _part = State(initialValue: start) }

    private var thisYear: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Part", selection: $part) {
                    Text("Year").tag(Part.year)
                    Text("Numbers").tag(Part.numbers)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // The Mac would draw a keyboard-focus ring in the system's own colour around the chosen part.
                .focusEffectDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .accessibilityIdentifier("year-switch")

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your reading")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity)
                        if part == .year { yearPart } else { numbersPart }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(colour: "purple"))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("year-done")
                }
            }
        }
        // The sheet sits above the shelves: a tapped book opens as a page inside it.
        .environment(\.openBook, nil)
        .sheet(item: Binding(get: { goalYear.map(YearID.init) }, set: { goalYear = $0?.year })) { item in
            GoalSheet(year: item.year, current: model.data.goal(year: item.year))
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
        .accessibilityIdentifier("year-page")
    }

    // MARK: Year

    @ViewBuilder private var yearPart: some View {
        let years = model.data.readingYears()
        ForEach(years) { year in
            yearSection(year)
        }
        let loose = model.data.finishedWithoutDay
        if !loose.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Day not known · \(loose.count)")
                    .font(.headline)
                    .foregroundStyle(Theme.text("grey"))
                    .accessibilityIdentifier("year-unknown-heading")
                ForEach(loose) { book in row(book, showDay: false) }
            }
        }
    }

    private func yearSection(_ year: ReadingYear) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(String(year.year)) · \(year.books.count == 1 ? "1 book" : "\(year.books.count) books")")
                    .font(.headline)
                    .foregroundStyle(Theme.text("purple"))
                    .accessibilityIdentifier("year-heading-\(year.year)")
                Spacer()
                if year.year == thisYear {
                    Button(year.goal.map { "Goal: \($0)" } ?? "Set goal") { goalYear = year.year }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text("purple"))
                        .accessibilityIdentifier("year-goal-button")
                }
            }
            if let goal = year.goal {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LibraryData.goalLine(finished: year.books.count, goal: goal, year: year.year))
                        .font(.subheadline)
                        .accessibilityIdentifier("year-goal-line-\(year.year)")
                    bar(value: year.books.count, of: goal, colour: "purple")
                        .frame(height: 6)
                }
            }
            if year.books.isEmpty {
                Text(year.year == thisYear ? "Nothing finished yet this year." : "Nothing finished.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(year.books) { book in row(book, showDay: true) }
        }
    }

    private func row(_ book: Book, showDay: Bool) -> some View {
        BookLink(id: book.id, pushes: true) {
            HStack(spacing: 8) {
                CoverView(book: book, width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title).font(.body).lineLimit(2)
                    Text(book.author).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    if let stars = book.rating, stars > 0 {
                        StarsView(rating: stars, size: 11)
                    }
                    if showDay, let day = book.finishedDay {
                        Text(day.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("year-book-\(book.id)")
    }

    private func bar(value: Int, of total: Int, colour: String) -> some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.text(colour).opacity(0.18))
                Capsule().fill(Theme.fill(colour))
                    .frame(width: box.size.width * min(1, CGFloat(value) / CGFloat(max(1, total))))
            }
        }
    }

    // MARK: Numbers

    @ViewBuilder private var numbersPart: some View {
        let n = model.data.numbers()
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                figure(n.owned, "Books")
                figure(n.wishes, "Wish list")
                figure(n.lockFree, "Lock-free")
                figure(n.boughtTwice, "Bought twice")
            }
            section("By store", n.stores, colour: "blue", store: true)
            section("By kind", n.kinds, colour: "purple")
            section("Reading", n.reading, colour: "green")
            section("By language", n.languages, colour: "teal")
            section("Bought per year", n.boughtByYear, colour: "amber")
            section("Finished per year", n.finishedByYear, colour: "purple")
            if let mean = n.meanStars {
                Text("Your stars: \(mean.formatted(.number.precision(.fractionLength(1)))) on average over \(n.rated) \(n.rated == 1 ? "book" : "books")")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Theme.text("amber"))
                    .accessibilityIdentifier("numbers-stars")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("numbers-page")
    }

    private func figure(_ value: Int, _ name: String) -> some View {
        VStack(spacing: 0) {
            Text("\(value)").font(.title3.weight(.bold)).foregroundStyle(Theme.text("purple"))
            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("numbers-figure-\(name)")
    }

    @ViewBuilder private func section(_ title: String, _ lines: [NumberLine], colour: String, store: Bool = false) -> some View {
        if !lines.isEmpty {
            let top = lines.map(\.count).max() ?? 1
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.text(colour))
                ForEach(lines) { line in
                    HStack(spacing: 8) {
                        Text(line.name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(width: 140, alignment: .leading)
                        let tint: Color = store
                            ? Theme.store(BookStore(rawValue: line.colour) ?? .own)
                            : Theme.fill(line.colour)
                        GeometryReader { box in
                            Capsule().fill(tint)
                                .frame(width: max(3, box.size.width * CGFloat(line.count) / CGFloat(max(1, top))))
                                .frame(maxHeight: .infinity, alignment: .leading)
                        }
                        .frame(height: 8)
                        Text("\(line.count)")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("numbers-line-\(title)-\(line.name)")
                }
            }
        }
    }
}

private struct YearID: Identifiable { let year: Int; var id: Int { year } }

/// A small page that changes something: Cancel and Save. Empty or 0 = no goal.
private struct GoalSheet: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let year: Int
    @State private var text: String

    init(year: Int, current: Int?) {
        self.year = year
        _text = State(initialValue: current.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How many books this year?")
                .font(.headline)
                .foregroundStyle(Theme.text("purple"))
            TextField("Number of books", text: $text)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .onSubmit(save)
                .accessibilityIdentifier("goal-field")
            Text("Empty or 0 means no goal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("goal-cancel")
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(FilledButton(colour: "purple"))
                    .accessibilityIdentifier("goal-save")
            }
        }
        .padding(16)
        .presentationDetents([.height(220)])
        #if os(macOS)
        .frame(width: 320)
        #endif
    }

    private func save() {
        let count = Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
        model.setGoal(count > 0 ? count : nil, year: year)
        dismiss()
    }
}
