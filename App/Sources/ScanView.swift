import AMSIcons
import ReadingCore
import SwiftUI
#if os(iOS)
import VisionKit
#endif

/// Scan a book's barcode in a shop: do I own it, and if not, put it on the wish list.
struct ScanView: View {
    @EnvironmentObject private var model: ReadingModel
    @Environment(\.dismiss) private var dismiss

    private enum Outcome {
        case unknown
        case owned(ISBNFound, Book)
        case wished(ISBNFound)
        case new(ISBNFound)
    }

    private let colour = "red"
    @State private var number = ""
    @State private var tooShort = false
    @State private var looking = false
    @State private var outcome: Outcome?
    @State private var added = false
    @State private var addByHand = false
    @State private var lastCode = ""
    @State private var lastCodeTime = Date.distantPast
    @State private var lookupID = 0
    @State private var cameraFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    cameraPart
                    numberPart
                    resultPart
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle("Scan a book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done") }
                        .buttonStyle(FilledButton(colour: colour))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("scan-done")
                }
            }
            .sheet(isPresented: $addByHand) {
                AddBookPage().environmentObject(model)
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }

    // MARK: Camera

    @ViewBuilder private var cameraPart: some View {
        #if os(iOS)
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable && !cameraFailed {
            BarcodeCamera(onCode: { code in handleCode(code) }, onFail: { cameraFailed = true })
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("scan-camera")
        } else {
            noCamera
        }
        #endif
    }

    #if os(iOS)
    private var noCamera: some View {
        Text("No camera here. Type the number under the barcode.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(10)
            .background(Theme.plate, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("scan-nocamera")
    }
    #endif

    // MARK: Number

    private var numberPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Number under the barcode", text: $number)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .onChange(of: number) { _, _ in tooShort = false }
                .onSubmit { lookUpTyped() }
                .accessibilityIdentifier("scan-number")
            if tooShort {
                Text("Type the 10 or 13 digits under the barcode.")
                    .font(.footnote)
                    .foregroundStyle(Theme.text("red"))
                    .accessibilityIdentifier("scan-number-short")
            }
            Button { lookUpTyped() } label: {
                Text("Look up").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(colour: colour))
            .accessibilityIdentifier("scan-lookup")
        }
    }

    // MARK: Result

    @ViewBuilder private var resultPart: some View {
        if looking {
            Text("Looking up…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("scan-looking")
        } else if let outcome {
            VStack(alignment: .leading, spacing: 8) {
                resultBody(outcome)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.plate, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("scan-result")
        }
    }

    @ViewBuilder private func resultBody(_ outcome: Outcome) -> some View {
        switch outcome {
        case .unknown:
            Text("This number is not in the book catalogue.")
                .font(.headline)
                .foregroundStyle(Theme.text("red"))
                .accessibilityIdentifier("scan-unknown")
            Button { addByHand = true } label: { Text("Add by hand").frame(maxWidth: .infinity) }
                .buttonStyle(FilledButton(colour: colour))
                .accessibilityIdentifier("scan-add-hand")
        case .owned(let found, let book):
            Text("You own this")
                .font(.headline)
                .foregroundStyle(Theme.text("green"))
                .accessibilityIdentifier("scan-owned")
            HStack(alignment: .top, spacing: 10) {
                CoverView(book: book, width: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title.isEmpty ? found.title : book.title).font(.body.weight(.semibold))
                    if !book.author.isEmpty { Text(book.author).font(.callout).foregroundStyle(.secondary) }
                    StoreMarks(book: book)
                    Text("in " + book.stores.map(\.name).joined(separator: " and "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        case .wished(let found):
            Text("Already on your wish list")
                .font(.headline)
                .foregroundStyle(Theme.text("blue"))
                .accessibilityIdentifier("scan-wished")
            titleLines(found)
        case .new(let found):
            Text("Not on your shelf")
                .font(.headline)
                .foregroundStyle(Theme.text(colour))
                .accessibilityIdentifier("scan-new")
            titleLines(found)
            if added {
                Text("Added to your wish list.")
                    .font(.callout)
                    .foregroundStyle(Theme.text("green"))
                    .accessibilityIdentifier("scan-added")
            } else if !model.readOnly {
                Button {
                    model.add(title: found.title, author: found.author, store: nil)
                    added = true
                } label: { Text("Add to wish list").frame(maxWidth: .infinity) }
                    .buttonStyle(FilledButton(colour: colour))
                    .accessibilityIdentifier("scan-add-wish")
            }
        }
    }

    private func titleLines(_ found: ISBNFound) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(found.title).font(.body.weight(.semibold))
            if !found.author.isEmpty { Text(found.author).font(.callout).foregroundStyle(.secondary) }
        }
    }

    // MARK: Looking up

    private func lookUpTyped() {
        let digits = number.filter(\.isNumber)
        guard digits.count == 10 || digits.count == 13 else {
            tooShort = true
            return
        }
        tooShort = false
        startLookup(digits)
    }

    /// A code from the camera: only book barcodes, and the same one again within 3 seconds is ignored.
    private func handleCode(_ code: String) {
        guard code.count == 13, code.hasPrefix("978") || code.hasPrefix("979") else { return }
        let now = Date()
        if code == lastCode && now.timeIntervalSince(lastCodeTime) < 3 { return }
        lastCode = code
        lastCodeTime = now
        number = code
        startLookup(code)
    }

    private func startLookup(_ isbn: String) {
        lookupID += 1
        let mine = lookupID
        looking = true
        outcome = nil
        added = false
        Task {
            let found = await ISBNLookup.find(isbn: isbn)
            guard mine == lookupID else { return }
            looking = false
            guard let found else { outcome = .unknown; return }
            if let book = model.data.ownedMatch(title: found.title, author: found.author) {
                outcome = .owned(found, book)
            } else if model.data.find(found.title).first(where: \.wish) != nil {
                outcome = .wished(found)
            } else {
                outcome = .new(found)
            }
        }
    }
}

#if os(iOS)
/// The live camera, reading EAN-13 barcodes.
private struct BarcodeCamera: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        let fail = onFail
        DispatchQueue.main.async {
            do { try controller.startScanning() } catch { fail() }
        }
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let code) = item, let value = code.payloadStringValue {
                    onCode(value)
                    return
                }
            }
        }
    }
}
#endif
