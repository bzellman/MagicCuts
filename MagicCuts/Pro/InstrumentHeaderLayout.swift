import SwiftUI

/// Keeps the same four controls alive while the source group folds into one row.
struct InstrumentHeaderLayout: Layout {
    var collapseProgress: CGFloat
    var stacked: Bool
    var maximumCompactWidth: CGFloat?

    var animatableData: CGFloat {
        get { collapseProgress }
        set { collapseProgress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available = proposal.width ?? 370
        let compactWidth = min(available, maximumCompactWidth ?? available)
        let progress = stacked ? 0 : min(1, max(0, collapseProgress))
        let width = available + (compactWidth - available) * progress
        return CGSize(width: width, height: frames(width: width, subviews: subviews).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            view.place(at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY),
                       anchor: .center, proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        guard subviews.count == 4 else { return [] }
        if stacked {
            var y: CGFloat = 0
            return subviews.map { view in
                let height = max(56, view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
                defer { y += height }
                return CGRect(x: 0, y: y, width: width, height: height)
            }
        }
        let expanded = expandedFrames(width: width, subviews: subviews)
        let compact = compactFrames(width: width, subviews: subviews)
        let progress = min(1, max(0, collapseProgress))
        // Container sizing and control placement use the same animation progress.
        return zip(expanded, compact).map { start, end in
            CGRect(x: start.minX + (end.minX - start.minX) * progress,
                   y: start.minY + (end.minY - start.minY) * progress,
                   width: start.width + (end.width - start.width) * progress,
                   height: start.height + (end.height - start.height) * progress)
        }
    }

    private func compactFrames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let utility: CGFloat = 44
        let source = min(150, max(84, width * 0.28))
        let instrument = max(44, width - source - utility * 2)
        let widths = [instrument, utility, source, utility]
        // Longer names wrap within their own cell, never into a second nav row.
        let height = zip(subviews, widths).map { view, width in
            max(56, view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
        }.max() ?? 56
        return [
            CGRect(x: 0, y: 0, width: instrument, height: height),
            CGRect(x: instrument + source, y: 0, width: utility, height: height),
            CGRect(x: instrument, y: 0, width: source, height: height),
            CGRect(x: width - utility, y: 0, width: utility, height: height)
        ]
    }

    private func expandedFrames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let first = (width - 0.5) / 2
        let source = width - 60.5
        let top = max(56, subviews[0].sizeThatFits(ProposedViewSize(width: first, height: nil)).height,
                      subviews[1].sizeThatFits(ProposedViewSize(width: first, height: nil)).height)
        let bottom = max(56, subviews[2].sizeThatFits(ProposedViewSize(width: source, height: nil)).height,
                         subviews[3].sizeThatFits(ProposedViewSize(width: 60, height: nil)).height)
        return [
            CGRect(x: 0, y: 0, width: first, height: top),
            CGRect(x: first + 0.5, y: 0, width: first, height: top),
            CGRect(x: 0, y: top + 0.5, width: source, height: bottom),
            CGRect(x: source + 0.5, y: top + 0.5, width: 60, height: bottom)
        ]
    }
}

/// Quantized scroll observations avoid rebuilding the instrument on every pixel.
enum InstrumentHeaderScrollRegion: Equatable {
    case top, middle, reading

    init(_ geometry: ScrollGeometry) {
        let extent = max(0, geometry.contentSize.height + geometry.contentInsets.top
                         + geometry.contentInsets.bottom - geometry.containerSize.height)
        let offset = min(extent, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
        // The gap exceeds the 56.5pt fold, so inset changes cannot flip the state back.
        self = offset <= 12 ? .top : offset >= 88 ? .reading : .middle
    }
}
