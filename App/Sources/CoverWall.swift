import ReadingCore
import SwiftUI

/// The cover wall: a shelf's books as a full grid of covers, no text beneath. One switch for all shelves,
/// remembered on this device: `@AppStorage(CoverWall.key) private var wall = false`.
struct CoverWall: View {
    static let key = "coverWall"

    let books: [Book]
    let colour: String

    #if os(iOS)
    private static let width: CGFloat = 96
    #else
    private static let width: CGFloat = 110
    #endif

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.width, maximum: Self.width + 14), spacing: 8, alignment: .top)],
                  spacing: 8) {
            ForEach(books) { book in
                BookLink(id: book.id) {
                    CoverView(book: book, width: Self.width)
                        .overlay(alignment: .bottom) {
                            if let done = LibraryData.coverProgress(book) {
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.black.opacity(0.45))
                                    Rectangle().fill(Color.white).frame(width: max(2, Self.width * done))
                                }
                                .frame(width: Self.width, height: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                                .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(book.title), \(book.author)")
                .accessibilityIdentifier("wall-\(book.id)")
            }
        }
        .padding(.horizontal, 12)
        .accessibilityIdentifier("cover-wall")
    }
}

/// The small toolbar button: list ⇄ wall. Shows the grid mark while the list shows, the list mark while the wall shows.
struct WallToggle: View {
    @Binding var wall: Bool
    let colour: String

    var body: some View {
        Button { wall.toggle() } label: {
            WallMark(grid: !wall)
                .stroke(Theme.text(colour), style: StrokeStyle(lineWidth: 1.9 * 18 / 24, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 18)
        }
        .help(wall ? "Show as list" : "Show as cover wall")
        .accessibilityLabel(wall ? "Show as list" : "Show as cover wall")
        .accessibilityIdentifier("wall-toggle")
    }
}

/// Two hand-drawn marks on a 24-point grid: four rounded squares, or three rows with a dot each.
private struct WallMark: Shape {
    let grid: Bool

    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        var path = Path()
        if grid {
            for (x, y) in [(3.5, 3.5), (13.5, 3.5), (3.5, 13.5), (13.5, 13.5)] as [(CGFloat, CGFloat)] {
                path.addRoundedRect(in: CGRect(x: rect.minX + x * k, y: rect.minY + y * k, width: 7 * k, height: 7 * k),
                                    cornerSize: CGSize(width: 1.8 * k, height: 1.8 * k))
            }
        } else {
            for y: CGFloat in [6, 12, 18] {
                path.move(to: p(9.5, y)); path.addLine(to: p(20.5, y))
                path.move(to: p(3.6, y)); path.addLine(to: p(3.7, y))
            }
        }
        return path
    }
}
