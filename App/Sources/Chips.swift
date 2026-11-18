import SwiftUI

/// Lays small choices out in rows, going on in the next row when one is full.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (i, point) in result.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (points, widest, y + rowHeight)
    }
}

/// A small rounded choice: full colour when chosen, an outline when not.
struct Chip: View {
    let title: String
    var count: Int?
    let colour: String
    let on: Bool
    /// A colour name for a dot before the words (a kind of note).
    var dot: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let dot {
                    Circle().fill(on ? Color.white : Theme.text(dot)).frame(width: 7, height: 7)
                }
                Text(title)
                if let count { Text("\(count)").opacity(0.75) }
            }
            .font(.subheadline)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(on ? Color.white : Theme.text(colour))
            .background(Capsule().fill(on ? Theme.fill(colour) : Color.clear))
            .overlay(Capsule().stroke(Theme.text(colour).opacity(on ? 0 : 0.45), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
