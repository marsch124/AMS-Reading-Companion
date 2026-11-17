import Foundation
import Security

/// What the app hands to the Home Screen widget. Plain Foundation and Security only:
/// this same file is compiled into the app and into the widget.
struct WidgetBook: Codable, Equatable {
    var id: String
    var title: String
    var author: String
    var coverURL: String?
    /// The text the tile colour is derived from: pass the book's title (same as Theme.tile(for: book.title)).
    var tint: String
}

struct WidgetSnapshot: Codable, Equatable {
    var reading: [WidgetBook]
    var next: WidgetBook?
    var nextReason: String?
}

/// The handful of books the widget shows travel through the device's keychain: the app keeps them in its own
/// keychain group, and the widget is let into that group (Widget.entitlements). Nothing leaves the device.
/// (An App Group would do the same, but it has to be registered by hand at Apple for every new part of the app;
/// the keychain group needs no registration.)
enum WidgetFiles {
    static let group = "D24ENP83QQ.com.schabbauer.AMSReadingCompanion"
    private static let service = "com.schabbauer.AMSReadingCompanion.widget"
    private static let account = "snapshot"

    private static var item: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrAccessGroup as String: group]
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let status = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var new = item
        new[kSecValueData as String] = data
        // Readable while the device is locked, once it was unlocked after a restart: a widget draws then too.
        new[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(new as CFDictionary, nil)
    }

    /// nil when the app has not written anything on this device yet.
    static func read() -> WidgetSnapshot? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
