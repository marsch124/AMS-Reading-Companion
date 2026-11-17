import ReadingCore
import SwiftUI
import UniformTypeIdentifiers

/// Settings: How it works, What's new, the three book lists, and the version.
/// Nothing here needs a Cancel: the two buttons act at once, so one Done button closes the page.
struct SettingsView: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickingFile = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "AMS Reading Companion \(number) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("How it works") { GuidePage() }
                        .accessibilityIdentifier("howItWorks")
                    NavigationLink("What's new") { NewsPage() }
                        .accessibilityIdentifier("whatsNew")
                }

                Section {
                    listRow(.apple, key: "apple")
                    listRow(.kindle, key: "kindle")
                    listRow(.kobo, key: "kobo")
                    if model.isMac, !model.readOnly {
                        Button(model.readingLists ? "Reading the lists…" : "Refresh") { model.readLists() }
                            .buttonStyle(FilledButton(colour: "purple"))
                            .disabled(model.readingLists)
                            .accessibilityIdentifier("refresh-lists")
                    }
                    if !model.readOnly {
                        Button("Import Kindle list…") { pickingFile = true }
                            .foregroundStyle(Theme.text("purple"))
                            .accessibilityIdentifier("import-kindle-file")
                    }
                    if let note = model.fileNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("import-file-note")
                    }
                } header: {
                    Text("Book lists")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.text("purple"))
                        .textCase(nil)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.isMac
                             ? "This Mac reads the lists each time AMS Reading opens. After buying a book, open the store's Mac app once so it knows the book."
                             : "The lists are read on your Mac and arrive here through iCloud.")
                        if !model.cloudOn {
                            Text("iCloud Drive is off on this device, so the shelf stays on this device only.")
                                .foregroundStyle(Theme.text("red"))
                                .accessibilityIdentifier("cloud-off")
                        }
                        Text(version)
                            .accessibilityIdentifier("versionLine")
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("settingsDone")
                }
            }
            .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.commaSeparatedText, .json, .plainText, .tabSeparatedText]) { result in
                if case .success(let url) = result { model.importKindleFile(url) }
            }
        }
        #if os(macOS)
        .frame(width: 560, height: 580)
        #endif
    }

    private func listRow(_ store: BookStore, key: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle().fill(Theme.store(store)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.name)
                Text(line(key))
                    .font(.footnote)
                    .foregroundStyle(model.storeTrouble[key] == nil ? Color.secondary : Theme.text("red"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("import-\(key)")
    }

    private func line(_ key: String) -> String {
        if let trouble = model.storeTrouble[key] { return trouble }
        guard let note = model.data.imports[key] else {
            return key == "kindle" ? "No Kindle books yet. Import your Kindle list, or add books by hand." : "Not read yet."
        }
        let when = DateFormatter()
        when.dateFormat = "d MMM yyyy, HH:mm"
        let books = note.count == 1 ? "1 book" : "\(note.count) books"
        return key == "kindle"
            ? "\(books) on the shelf · last change \(when.string(from: note.date))"
            : "\(books) · read \(when.string(from: note.date))"
    }
}

private let settingsColour = "purple"

struct GuidePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Guide.guide) { part in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(part.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text(settingsColour))
                        ForEach(part.text, id: \.self) { line in
                            Text(line).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("How it works")
        .accessibilityIdentifier("guidePage")
    }
}

struct NewsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Guide.news) { release in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Version \(release.version)")
                            .font(.headline)
                            .foregroundStyle(Theme.text(settingsColour))
                        Text(release.date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(release.items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Circle().fill(Theme.text(settingsColour)).frame(width: 5, height: 5)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                                Text(item).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("What's new")
        .accessibilityIdentifier("newsPage")
    }
}
