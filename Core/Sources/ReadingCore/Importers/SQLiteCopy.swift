#if os(macOS)
import Foundation
import SQLite3

/// A value read from a SQLite cell.
struct SQLCell {
    var text: String?
    var number: Double?
    var isNull: Bool { text == nil && number == nil }
    var string: String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            if let n = number { return n == n.rounded() ? String(Int64(n)) : String(n) }
            return nil
        }
        return t
    }
    var double: Double? { number ?? text.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
    var int: Int? { double.map { Int($0) } }
}

typealias SQLRow = [String: SQLCell]

enum ImporterError: Error { case cannotOpen(String) }

/// Opens a read-only COPY of a database (plus -wal and -shm) in a fresh temporary folder, and deletes it afterwards.
/// The live file is never opened.
struct SQLiteCopy {
    let db: OpaquePointer

    static func with<T>(_ source: URL, _ body: (SQLiteCopy) throws -> T) throws -> T {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("ReadingCompanion-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        let copy = tmp.appendingPathComponent(source.lastPathComponent)
        try fm.copyItem(at: source, to: copy)
        for suffix in ["-wal", "-shm"] {
            let side = URL(fileURLWithPath: source.path + suffix)
            if fm.fileExists(atPath: side.path) {
                try? fm.copyItem(at: side, to: URL(fileURLWithPath: copy.path + suffix))
            }
        }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
            sqlite3_close(handle)
            throw ImporterError.cannotOpen(source.lastPathComponent)
        }
        defer { sqlite3_close(db) }
        return try body(SQLiteCopy(db: db))
    }

    /// Column names of a table (empty when the table does not exist).
    func columns(of table: String) -> Set<String> {
        var names = Set<String>()
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\"\(table)\")", -1, &st, nil) == SQLITE_OK else { return names }
        defer { sqlite3_finalize(st) }
        while sqlite3_step(st) == SQLITE_ROW {
            if let c = sqlite3_column_text(st, 1) { names.insert(String(cString: c)) }
        }
        return names
    }

    /// Selects the wanted columns that really exist. Missing table or error gives an empty list.
    func rows(table: String, wanted: [String], whereClause: String? = nil) -> [SQLRow] {
        let have = columns(of: table)
        let cols = wanted.filter { have.contains($0) }
        guard !cols.isEmpty else { return [] }
        let sql = "SELECT " + cols.map { "\"\($0)\"" }.joined(separator: ",") + " FROM \"\(table)\""
            + (whereClause.map { " WHERE " + $0 } ?? "")
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(st) }
        var out: [SQLRow] = []
        while sqlite3_step(st) == SQLITE_ROW {
            var row = SQLRow()
            for (i, name) in cols.enumerated() {
                let idx = Int32(i)
                switch sqlite3_column_type(st, idx) {
                case SQLITE_INTEGER, SQLITE_FLOAT:
                    row[name] = SQLCell(text: nil, number: sqlite3_column_double(st, idx))
                case SQLITE_TEXT:
                    row[name] = SQLCell(text: String(cString: sqlite3_column_text(st, idx)), number: nil)
                default:
                    row[name] = SQLCell(text: nil, number: nil)
                }
            }
            out.append(row)
        }
        return out
    }
}
#endif
