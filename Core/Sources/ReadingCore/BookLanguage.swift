import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Language codes of books: reading what a store says, naming it, and a careful guess from a title.
public enum BookLanguage {
    private static let threeLetter: [String: String] = [
        "swe": "sv", "sve": "sv", "ger": "de", "deu": "de", "eng": "en", "dan": "da", "dut": "nl", "nld": "nl",
        "fre": "fr", "fra": "fr", "spa": "es", "ita": "it", "nor": "no", "nob": "nb", "fin": "fi",
        "por": "pt", "rus": "ru", "pol": "pl", "jpn": "ja", "zho": "zh", "chi": "zh", "lat": "la"]
    private static let names: [String: String] = [
        "swedish": "sv", "german": "de", "english": "en", "danish": "da", "norwegian": "no", "finnish": "fi",
        "dutch": "nl", "french": "fr", "spanish": "es", "italian": "it", "portuguese": "pt",
        "svenska": "sv", "deutsch": "de", "english (united states)": "en"]

    /// "sv-SE", "swe", "Swedish", "SV" → "sv". nil for empty or unknown text.
    public static func code(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return nil }
        if let n = names[t] { return n }
        let head = t.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? t
        guard head.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        if head.count == 2 { return head }
        if head.count == 3 { return threeLetter[head] }
        return nil
    }

    /// "sv" → "Swedish" (English names).
    public static func name(_ code: String) -> String {
        switch code.lowercased() {
        case "sv": return "Swedish"
        case "de": return "German"
        case "en": return "English"
        default:
            return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        }
    }

    /// A careful guess from a title when no store says the language: only "sv", "de" or "en", nil when unsure.
    public static func guess(title: String) -> String? {
        let t = title.lowercased()
        if t.contains("å") { return "sv" }
        if t.contains("ß") { return "de" }
        let letters = t.filter { $0.isLetter }.count
        guard letters >= 12 else { return nil }
        #if canImport(NaturalLanguage)
        let r = NLLanguageRecognizer()
        r.languageConstraints = [.swedish, .german, .english]
        r.processString(title)
        let h = r.languageHypotheses(withMaximum: 3)
        guard let top = h.max(by: { $0.value < $1.value }), top.value >= 0.8 else { return nil }
        switch top.key {
        case .swedish: return "sv"
        case .german: return "de"
        case .english: return "en"
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
