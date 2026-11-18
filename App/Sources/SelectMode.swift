import ReadingCore
import SwiftUI

/// "Change several at once": the ticked books of a page, handed down to the covers.
struct BookSelection {
    var ids: Set<String>
    var colour: String
    var toggle: (String) -> Void
}

private struct BookSelectionKey: EnvironmentKey {
    static let defaultValue: BookSelection? = nil
}

extension EnvironmentValues {
    /// Set only while a page is in its selecting mode: a tap on a cover ticks it instead of opening the book.
    var bookSelection: BookSelection? {
        get { self[BookSelectionKey.self] }
        set { self[BookSelectionKey.self] = newValue }
    }
}

/// A hand-drawn tick on a 24-point grid: a ring and a check.
private struct TickShape: Shape {
    let ticked: Bool
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + 3 * k, y: rect.minY + 3 * k, width: 18 * k, height: 18 * k))
        if ticked {
            path.move(to: p(7.8, 12.4)); path.addLine(to: p(10.8, 15.4)); path.addLine(to: p(16.4, 8.8))
        }
        return path
    }
}

struct SelectTick: View {
    let ticked: Bool
    let colour: String

    var body: some View {
        ZStack {
            if ticked { Circle().fill(Theme.fill(colour)).padding(2.5) }
            else { Circle().fill(Color.black.opacity(0.25)).padding(2.5) }
            TickShape(ticked: ticked)
                .stroke(ticked ? Color.white : Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.9 * 24 / 24, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
        .shadow(color: .black.opacity(0.25), radius: 1)
        .accessibilityHidden(true)
    }
}

private struct SelectableCover: ViewModifier {
    let id: String
    @Environment(\.bookSelection) private var selection

    func body(content: Content) -> some View {
        if let selection {
            let on = selection.ids.contains(id)
            content
                // The book's own link gets no touch, so a tick never opens the book.
                .allowsHitTesting(false)
                .opacity(on ? 1 : 0.55)
                // At the bottom: the top of a cover without a picture holds its title.
                .overlay(alignment: .bottomTrailing) { SelectTick(ticked: on, colour: selection.colour).padding(4) }
                .contentShape(Rectangle())
                .onTapGesture { selection.toggle(id) }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(on ? "Ticked" : "Not ticked")
                .accessibilityIdentifier("select-tick-\(id)")
        } else {
            content
        }
    }
}

extension View {
    /// While the page is selecting: the cover ticks on a tap and carries a tick mark.
    func selectableCover(_ id: String) -> some View { modifier(SelectableCover(id: id)) }

    /// Adds the selecting mode to a page that shows `books`.
    func selectMode(books: [Book], colour: String, selecting: Binding<Bool>, ids: Binding<Set<String>>) -> some View {
        modifier(SelectModeModifier(books: books, colour: colour, selecting: selecting, ids: ids))
    }
}

private struct SelectModeModifier: ViewModifier {
    @EnvironmentObject private var model: ReadingModel
    let books: [Book]
    let colour: String
    @Binding var selecting: Bool
    @Binding var ids: Set<String>
    @State private var tagging = false
    @State private var confirmingAway = false

    private var shown: [String] { books.map(\.id) }
    private var picked: [String] { shown.filter { ids.contains($0) } }

    private func finish() { ids = []; selecting = false }

    func body(content: Content) -> some View {
        content
            .environment(\.bookSelection, selecting ? BookSelection(ids: ids, colour: colour) { id in
                if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            } : nil)
            .toolbar {
                if selecting {
                    ToolbarItem(placement: .principal) {
                        Text(picked.isEmpty ? "None selected" : "\(picked.count) selected")
                            .font(.headline)
                            .foregroundStyle(Theme.text(colour))
                            .accessibilityIdentifier("select-count")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("All") { ids = Set(shown) }
                            .foregroundStyle(Theme.text(colour))
                            .accessibilityIdentifier("select-all")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") { finish() }
                            .foregroundStyle(Theme.text(colour))
                            .keyboardShortcut(.cancelAction)
                            .accessibilityIdentifier("select-done")
                    }
                } else if !model.readOnly {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Select") { selecting = true }
                            .foregroundStyle(Theme.text(colour))
                            .help("Change several books at once")
                            .accessibilityIdentifier("select-start")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if selecting { bar }
            }
            .onChange(of: shown) { _, now in ids.formIntersection(now) }
            .sheet(isPresented: $tagging) {
                SelectTagPage(count: picked.count) { tag in
                    model.addTag(tag, toAll: picked)
                    finish()
                }
            }
            .confirmationDialog("Put \(ownedPicked) \(ownedPicked == 1 ? "book" : "books") away?",
                                isPresented: $confirmingAway, titleVisibility: .visible) {
                Button("Put away", role: .destructive) {
                    model.setPutAway(true, of: picked)
                    finish()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
Text("Put \(ownedPicked) \(ownedPicked == 1 ? "book" : "books") away? They leave every shelf; the search still finds them, and Settings takes them out again."
                     + (ownedPicked < picked.count ? " Wishes stay where they are." : ""))
            }
    }

    /// How many of the ticked books are owned: a wish cannot be put away.
    private var ownedPicked: Int { picked.filter { model.data.book($0).map { !$0.copies.isEmpty } ?? false }.count }

    private var bar: some View {
        let none = picked.isEmpty
        return HStack(spacing: 6) {
            barButton("Tag…", id: "select-tag") { tagging = true }
            Menu {
                ForEach(ReadStatus.allCases, id: \.self) { status in
                    Button(Self.name(status)) {
                        model.setStatus(status, ofAll: picked)
                        finish()
                    }
                }
            } label: { barLabel("Status") }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityIdentifier("select-status")
            barButton("Up next", id: "select-upnext") {
                model.addUpNext(all: picked)
                finish()
            }
            barButton("Put away", id: "select-putaway") { confirmingAway = true }
        }
        .disabled(none)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func barButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { barLabel(title) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
    }

    private func barLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(Theme.fill(colour), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }

    static func name(_ status: ReadStatus) -> String {
        switch status {
        case .unread: return "Not read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        }
    }
}

/// One tag for the ticked books: typed, or tapped from the tags already in use.
struct SelectTagPage: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    let count: Int
    let add: (String) -> Void
    @State private var text = ""

    private let colour = "teal"

    private var clean: String { LibraryData.cleanTags([text]).first ?? "" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let tags = model.data.allTags()
                    if tags.isEmpty {
                        Text("No tags yet. Type one, for example “travel” or “to give away”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ChipFlow {
                            ForEach(tags, id: \.tag) { item in
                                Chip(title: item.tag, count: item.count, colour: colour,
                                     on: LibraryData.tagKey(item.tag) == LibraryData.tagKey(text)) { text = item.tag }
                                    .accessibilityIdentifier("select-tag-\(LibraryData.tagKey(item.tag))")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Tags in use").foregroundStyle(Theme.text(colour))
                }
                Section {
                    TextField("Tag", text: $text)
                        .onSubmit(save)
                        .accessibilityIdentifier("select-tag-field")
                } header: {
                    Text("Add to \(count) \(count == 1 ? "book" : "books")").foregroundStyle(Theme.text(colour))
                }
            }
            .navigationTitle("Tag")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("select-tag-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .buttonStyle(FilledButton(colour: colour))
                        .keyboardShortcut(.defaultAction)
                        .disabled(clean.isEmpty)
                        .accessibilityIdentifier("select-tag-add")
                }
            }
        }
        #if os(macOS)
        .frame(width: 440, height: 400)
        #endif
    }

    private func save() {
        guard !clean.isEmpty else { return }
        let tag = clean
        dismiss()
        add(tag)
    }
}
