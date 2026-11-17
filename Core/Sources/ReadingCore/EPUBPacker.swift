import Foundation
import Compression

/// Packs an EPUB that Apple Books keeps as a folder into one proper `.epub` file.
public enum EPUBPacker {
    public enum Trouble: Error { case notAFolder, noMimetype, tooBig, cannotWrite }

    /// True when this path is an EPUB kept as a folder.
    public static func isFolderBook(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "epub" else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Packs an EPUB kept as a folder into one .epub file. The folder is only read.
    public static func pack(folder: URL, to file: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { throw Trouble.notAFolder }
        var mimeIsDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.appendingPathComponent("mimetype").path, isDirectory: &mimeIsDir), !mimeIsDir.boolValue else {
            throw Trouble.noMimetype
        }

        var names: [String] = []
        collect(folder, prefix: "", into: &names)
        names.removeAll { $0 == "mimetype" }
        names.sort()
        names.insert("mimetype", at: 0)
        if names.count > 65_535 { throw Trouble.tooBig }

        let tmp = file.deletingLastPathComponent().appendingPathComponent(".\(file.lastPathComponent).\(UUID().uuidString).tmp")
        guard fm.createFile(atPath: tmp.path, contents: nil), let handle = try? FileHandle(forWritingTo: tmp) else {
            throw Trouble.cannotWrite
        }
        func fail(_ error: Error) -> Error {
            try? handle.close()
            try? fm.removeItem(at: tmp)
            return error
        }

        struct Entry { let name: Data; let method: UInt16; let crc: UInt32; let csize: UInt32; let usize: UInt32; let offset: UInt32 }
        var entries: [Entry] = []
        var position: UInt64 = 0
        let dosTime: UInt16 = 0
        let dosDate: UInt16 = (20 << 9) | (1 << 5) | 1   // 1 Jan 2000, fixed so output is repeatable

        do {
            for name in names {
                guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else { throw Trouble.cannotWrite }
                guard data.count < 0xFFFF_FFFF, position < 0xFFFF_FFFF else { throw Trouble.tooBig }
                let crc = crc32(data)
                var method: UInt16 = 0
                var payload = data
                if name != "mimetype", data.count > 0, let packed = deflate(data), packed.count < data.count {
                    method = 8
                    payload = packed
                }
                let nameData = Data(name.utf8)
                var head = Data()
                head.le32(0x0403_4b50); head.le16(20); head.le16(0x0800); head.le16(method)
                head.le16(dosTime); head.le16(dosDate); head.le32(crc)
                head.le32(UInt32(payload.count)); head.le32(UInt32(data.count))
                head.le16(UInt16(nameData.count)); head.le16(0)
                head.append(nameData)
                entries.append(Entry(name: nameData, method: method, crc: crc, csize: UInt32(payload.count),
                                     usize: UInt32(data.count), offset: UInt32(position)))
                try handle.write(contentsOf: head)
                try handle.write(contentsOf: payload)
                position += UInt64(head.count + payload.count)
                if position >= 0xFFFF_FFFF { throw Trouble.tooBig }
            }
            let centralStart = position
            var central = Data()
            for e in entries {
                central.le32(0x0201_4b50); central.le16(20); central.le16(20); central.le16(0x0800); central.le16(e.method)
                central.le16(dosTime); central.le16(dosDate); central.le32(e.crc)
                central.le32(e.csize); central.le32(e.usize)
                central.le16(UInt16(e.name.count)); central.le16(0); central.le16(0)
                central.le16(0); central.le16(0); central.le32(0); central.le32(e.offset)
                central.append(e.name)
            }
            let centralSize = central.count
            guard centralStart + UInt64(centralSize) < 0xFFFF_FFFF else { throw Trouble.tooBig }
            central.le32(0x0605_4b50); central.le16(0); central.le16(0)
            central.le16(UInt16(entries.count)); central.le16(UInt16(entries.count))
            central.le32(UInt32(centralSize)); central.le32(UInt32(centralStart)); central.le16(0)
            try handle.write(contentsOf: central)
            try handle.close()
        } catch {
            throw fail(error)
        }

        do {
            if fm.fileExists(atPath: file.path) {
                _ = try fm.replaceItemAt(file, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: file)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw Trouble.cannotWrite
        }
    }

    // MARK: - Helpers

    private static func collect(_ dir: URL, prefix: String, into names: inout [String]) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        for item in items {
            if item.hasPrefix(".") || item.hasPrefix("iTunes") { continue }
            let url = dir.appendingPathComponent(item)
            // A link is never followed: it could lead out of the book, or round in a circle.
            if (try? fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                collect(url, prefix: prefix + item + "/", into: &names)
            } else {
                names.append(prefix + item)
            }
        }
    }

    private static func deflate(_ data: Data) -> Data? {
        let capacity = data.count + 1024
        var out = [UInt8](repeating: 0, count: capacity)
        let n = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(&out, capacity, base, data.count, nil, COMPRESSION_ZLIB)
        }
        return n > 0 ? Data(out[0..<n]) : nil
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func le16(_ v: UInt16) { append(UInt8(v & 0xFF)); append(UInt8(v >> 8)) }
    mutating func le32(_ v: UInt32) { le16(UInt16(v & 0xFFFF)); le16(UInt16(v >> 16)) }
}
