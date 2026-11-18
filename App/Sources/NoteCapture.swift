import AMSIcons
import AVFoundation
import Speech
import SwiftUI
import UniformTypeIdentifiers
import Vision
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// Reusable pieces for reading notes: the lines of a photographed page, and dictation by voice.

// MARK: - Page text

enum PageTextReader {
    /// The lines of text on a picture, top to bottom. Runs off the main thread.
    static func lines(in image: CGImage) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["sv-SE", "en-GB", "de-DE"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do { try handler.perform([request]) } catch {
                    cont.resume(returning: [])
                    return
                }
                let found = (request.results ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
                let lines = found
                    .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                cont.resume(returning: lines)
            }
        }
    }

    /// One text from chosen lines: a line ending in a hyphen joins the next one without it, the others join with a space.
    static func join(_ lines: [String]) -> String {
        var out = ""
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if out.isEmpty {
                out = line
            } else if out.hasSuffix("-") {
                out.removeLast()
                out += line
            } else {
                out += " " + line
            }
        }
        return out
    }
}

// MARK: - Dictation

@MainActor
final class Dictation: ObservableObject {
    @Published var text = ""
    @Published var running = false
    @Published var trouble: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recogniser: SFSpeechRecognizer?
    /// Between a press on Speak and the answer to the permission questions: a second press must not start twice.
    private var starting = false

    /// language: "sv", "de", "en", or nil for the device's language.
    func start(language: String?) {
        guard !running, !starting else { return }
        starting = true
        trouble = nil
        let locale: Locale
        switch language?.lowercased() {
        case "sv": locale = Locale(identifier: "sv-SE")
        case "de": locale = Locale(identifier: "de-DE")
        case "en": locale = Locale(identifier: "en-GB")
        default: locale = Locale.current
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                if status != .authorized { self.starting = false }
                switch status {
                case .authorized: self.askMicrophone(locale)
                case .denied: self.trouble = "Speech is not allowed for this app. Turn it on in Settings › Privacy."
                case .restricted: self.trouble = "Speech recognition is switched off on this device."
                default: self.trouble = "Speech is not allowed for this app. Turn it on in Settings › Privacy."
                }
            }
        }
    }

    private func askMicrophone(_ locale: Locale) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted { self.begin(locale) } else {
                    self.starting = false
                    self.trouble = "The microphone is not allowed for this app. Turn it on in Settings › Privacy."
                }
            }
        }
    }

    private func begin(_ locale: Locale) {
        starting = false
        guard !running else { return }
        guard let recogniser = SFSpeechRecognizer(locale: locale), recogniser.isAvailable else {
            trouble = "Speech recognition is not available for this language right now."
            return
        }
        self.recogniser = recogniser
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recogniser.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            trouble = "The microphone could not be started."
            return
        }
        #endif
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            trouble = "No microphone was found."
            quiet()
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch {
            trouble = "The microphone could not be started."
            input.removeTap(onBus: 0)
            quiet()
            return
        }
        running = true
        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.text = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true { self.finish() }
            }
        }
    }

    func stop() {
        request?.endAudio()
        finish()
    }

    /// Gives the sound back to other apps after a start that failed.
    private func quiet() {
        request = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func finish() {
        // Nothing was started (the note page closes without Speak ever pressed): leave the microphone alone.
        guard running || engine.isRunning || task != nil else { return }
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        if running {
            running = false
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }
}

// MARK: - Photo of the page

struct PagePhotoButton: View {
    let colour: String
    let onText: (String) -> Void

    @State private var picking = false
    @State private var picked: CGImage?
    @State private var showLines = false
    @State private var trouble: String?

    init(colour: String, onText: @escaping (String) -> Void) {
        self.colour = colour
        self.onText = onText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { picking = true } label: {
                HStack(spacing: 6) {
                    ControlMarkView(.photo, size: 18, colour: Theme.text(colour))
                    Text("Photo of the page").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.text(colour))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("note-photo")
            if let trouble {
                Text(trouble).font(.footnote).foregroundStyle(Theme.text("red"))
            }
        }
        #if os(iOS)
        // The lines page opens only once the camera has closed: two pages cannot come up at the same moment.
        .fullScreenCover(isPresented: $picking, onDismiss: { if picked != nil { showLines = true } }) {
            ImagePicker { image in
                picked = image?.normalised().cgImage
                picking = false
            }
            .ignoresSafeArea()
        }
        #else
        .fileImporter(isPresented: $picking, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let image = NSImage(contentsOf: url),
                   let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    trouble = nil
                    picked = cg
                    showLines = true
                } else {
                    trouble = "That file is not a picture I can read."
                }
            case .failure:
                trouble = "The picture could not be opened."
            }
        }
        #endif
        .sheet(isPresented: $showLines) {
            if let picked {
                PageLinesPage(image: picked, colour: colour) { text in onText(text) }
            }
        }
    }
}

#if os(iOS)
private extension UIImage {
    /// Pixels turned upright, so the reader sees the page the right way round.
    func normalised() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    let onDone: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // No camera (the simulator): the photo library instead.
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onDone: (UIImage?) -> Void
        init(_ onDone: @escaping (UIImage?) -> Void) { self.onDone = onDone }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onDone(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onDone(nil) }
    }
}
#endif

// MARK: - The lines

struct PageLinesPage: View {
    @Environment(\.dismiss) private var dismiss
    let colour: String
    let onUse: (String) -> Void
    private let image: CGImage?

    @State private var lines: [String]
    @State private var ticked: Set<Int> = []
    @State private var reading: Bool

    /// From a picture: reads the lines when it appears.
    init(image: CGImage, colour: String = "purple", onUse: @escaping (String) -> Void) {
        self.image = image
        self.colour = colour
        self.onUse = onUse
        _lines = State(initialValue: [])
        _reading = State(initialValue: true)
    }

    /// With fixed lines (pictures and tests): no camera needed.
    init(lines: [String], colour: String = "purple", onUse: @escaping (String) -> Void = { _ in }) {
        self.image = nil
        self.colour = colour
        self.onUse = onUse
        _lines = State(initialValue: lines)
        _reading = State(initialValue: false)
    }

    private var useTitle: String {
        ticked.isEmpty ? "Use all lines" : "Use \(ticked.count) \(ticked.count == 1 ? "line" : "lines")"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if reading {
                    Text("Reading the page…")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .accessibilityIdentifier("lines-reading")
                    Spacer()
                } else if lines.isEmpty {
                    Text("No words found on this picture.")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .accessibilityIdentifier("lines-none-found")
                    Spacer()
                } else {
                    HStack(spacing: 10) {
                        Button("All") { ticked = Set(lines.indices) }
                            .accessibilityIdentifier("lines-all")
                        Button("None") { ticked = [] }
                            .accessibilityIdentifier("lines-none")
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text(colour))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                row(index, line)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                bottomBar
            }
            .navigationTitle("Lines")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task {
            guard reading, let image else { return }
            lines = await PageTextReader.lines(in: image)
            reading = false
        }
        .accessibilityIdentifier("page-lines")
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    private func row(_ index: Int, _ line: String) -> some View {
        let on = ticked.contains(index)
        return Button {
            if on { ticked.remove(index) } else { ticked.insert(index) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ControlMarkView(on ? .ticked : .circle, size: 20, colour: on ? Theme.text(colour) : .secondary)
                Text(line)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("lines-row-\(index)")
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("lines-cancel")
            Spacer()
            Button {
                let chosen = ticked.isEmpty ? lines : ticked.sorted().map { lines[$0] }
                onUse(PageTextReader.join(chosen))
                dismiss()
            } label: { Text(useTitle) }
                .buttonStyle(FilledButton(colour: colour))
                .keyboardShortcut(.defaultAction)
                .disabled(reading || lines.isEmpty)
                .accessibilityIdentifier("lines-use")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
