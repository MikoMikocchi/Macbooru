import SwiftUI

// Простой flow layout для чипов в сайдбаре (переименован, чтобы не конфликтовать с другими реализациями)
struct ChipsFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: nil, height: nil))
            if currentRowWidth > 0 && currentRowWidth + spacing + size.width > maxWidth {
                // перенос строки
                totalHeight += currentRowHeight + rowSpacing
                maxLineWidth = max(maxLineWidth, currentRowWidth)
                currentRowWidth = 0
                currentRowHeight = 0
            }
            if currentRowWidth > 0 { currentRowWidth += spacing }
            currentRowWidth += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        maxLineWidth = max(maxLineWidth, currentRowWidth)
        totalHeight += currentRowHeight
        return CGSize(width: maxLineWidth.isFinite ? maxLineWidth : 0, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: nil, height: nil))
            if x != bounds.minX && x + spacing + size.width > bounds.maxX {
                // перенос строки
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            if x != bounds.minX { x += spacing }
            sub.place(
                at: CGPoint(x: x, y: y), anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}
