#if canImport(CoreText)
import CoreGraphics
import CoreText
import Foundation

/// The whole shelf as a printable list: A4 upright pages, drawn with CoreGraphics and CoreText
/// (the same on iPhone, iPad and Mac). Heading and count on page 1, a header row on every page,
/// wishes last under "Wish list", a page number at the foot.
public enum ShelfListPDF {
    private static let pageW: CGFloat = 595.28, pageH: CGFloat = 841.89
    private static let margin: CGFloat = 40
    private static let rowH: CGFloat = 15
    private static let footer: CGFloat = 34
    // Title, Author, Series, Stores, Status, Stars: widths add up to the text width (515.28).
    private static let widths: [CGFloat] = [150, 100, 95, 88, 52, 30.28]
    private static let heads = ["Title", "Author", "Series", "Stores", "Status", "Stars"]

    public static func make(_ data: LibraryData, now: Date = Date()) -> Data {
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out as CFMutableData) else { return Data() }
        var box = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &box, [kCGPDFContextTitle as String: "My books"] as CFDictionary) else { return Data() }

        let books = data.listBooks
        let owned = books.filter { !$0.wish }
        let wishes = books.filter { $0.wish }

        enum Row { case book(Book), heading(String) }
        var rows: [Row] = owned.map { .book($0) }
        if !wishes.isEmpty { rows.append(.heading("Wish list")); rows += wishes.map { .book($0) } }

        // Lay the rows out into pages first, so "3 / 9" knows its total.
        var pages: [[Row]] = [[]]
        var room = pageH - margin - footer - 78 - rowH          // page 1 has the heading block
        for row in rows {
            var need = rowH
            if case .heading = row { need = rowH + 14 }
            if room < need { pages.append([]); room = pageH - margin - footer - rowH - 6 }
            pages[pages.count - 1].append(row)
            room -= need
        }

        let day = DateFormatter()
        day.locale = Locale(identifier: "en_GB")
        day.dateFormat = "d MMMM yyyy"
        let sub = "\(day.string(from: now)) · \(owned.count) \(owned.count == 1 ? "book" : "books") · \(wishes.count) on the wish list"

        let ink = CGColor(gray: 0.1, alpha: 1), grey = CGColor(gray: 0.45, alpha: 1), rule = CGColor(gray: 0.82, alpha: 1)

        for (index, page) in pages.enumerated() {
            ctx.beginPDFPage(nil)
            // Flip to top-left origin; text is drawn with its own un-flipped matrix.
            ctx.translateBy(x: 0, y: pageH)
            ctx.scaleBy(x: 1, y: -1)
            var y = margin
            if index == 0 {
                text(ctx, "My books", x: margin, baseline: y + 22, size: 24, bold: true, colour: ink)
                y += 32
                text(ctx, sub, x: margin, baseline: y + 10, size: 10, bold: false, colour: grey)
                y += 26
            }
            // Header row
            var x = margin
            for (i, h) in heads.enumerated() {
                text(ctx, h, x: x, baseline: y + 10.5, size: 9, bold: true, colour: ink)
                x += widths[i]
            }
            y += rowH
            line(ctx, y: y - 2, colour: ink)
            for row in page {
                switch row {
                case .heading(let t):
                    y += 14
                    text(ctx, t, x: margin, baseline: y + 8, size: 11, bold: true, colour: ink)
                    y += rowH
                    line(ctx, y: y - 2, colour: ink)
                case .book(let b):
                    var series = b.series ?? ""
                    if let n = b.seriesNumber, !series.isEmpty { series += " " + (n == n.rounded() ? String(Int(n)) : String(n)) }
                    let cells = LibraryData.listCells(b)
                    let status = cells[7]
                    let stars = b.rating.map(String.init) ?? ""
                    let values = [b.title, b.author, series, cells[4], status, stars]
                    var cx = margin
                    for (i, v) in values.enumerated() {
                        text(ctx, v, x: cx, baseline: y + 10.5, size: 9, bold: false, colour: ink, width: widths[i] - 6)
                        cx += widths[i]
                    }
                    y += rowH
                    line(ctx, y: y - 2, colour: rule)
                }
            }
            let foot = "\(index + 1) / \(pages.count)"
            let w = width(foot, size: 9, bold: false)
            text(ctx, foot, x: pageW / 2 - w / 2, baseline: pageH - margin + 4, size: 9, bold: false, colour: grey)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return out as Data
    }

    private static func line(_ ctx: CGContext, y: CGFloat, colour: CGColor) {
        ctx.setStrokeColor(colour)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageW - margin, y: y))
        ctx.strokePath()
    }

    private static func font(_ size: CGFloat, _ bold: Bool) -> CTFont {
        CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
    }

    private static func attributed(_ s: String, size: CGFloat, bold: Bool, colour: CGColor) -> CFAttributedString {
        let attrs: [CFString: Any] = [kCTFontAttributeName: font(size, bold), kCTForegroundColorAttributeName: colour]
        return CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary)
    }

    private static func width(_ s: String, size: CGFloat, bold: Bool) -> CGFloat {
        let l = CTLineCreateWithAttributedString(attributed(s, size: size, bold: bold, colour: CGColor(gray: 0, alpha: 1)))
        return CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
    }

    /// Draws one line of text at `baseline` (counted from the top). Cut with "…" when wider than `width`.
    private static func text(_ ctx: CGContext, _ s: String, x: CGFloat, baseline: CGFloat, size: CGFloat, bold: Bool,
                             colour: CGColor, width limit: CGFloat? = nil) {
        guard !s.isEmpty else { return }
        var line = CTLineCreateWithAttributedString(attributed(s, size: size, bold: bold, colour: colour))
        if let limit, CTLineGetTypographicBounds(line, nil, nil, nil) > Double(limit) {
            let dots = CTLineCreateWithAttributedString(attributed("…", size: size, bold: bold, colour: colour))
            if let cut = CTLineCreateTruncatedLine(line, Double(limit), .end, dots) { line = cut }
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: x, y: baseline)
        ctx.scaleBy(x: 1, y: -1)           // undo the page flip so the letters stand upright
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
#endif
