import SwiftUI

enum InstrumentHeaderMetrics {
    static let row: CGFloat = 56
    static let gap: CGFloat = 0.5
    static let verticalPadding: CGFloat = 16
    static let extraRow: CGFloat = row + gap
    static let compactChrome: CGFloat = row + verticalPadding
    static let restoreThreshold: CGFloat = 12
    static let overflowThreshold: CGFloat = 88

    static func progress(offset: CGFloat, extent: CGFloat) -> CGFloat {
        let overflow = max(0, extent - extraRow)
        guard overflow >= overflowThreshold else { return 0 }
        let travel = max(0, offset)
        guard travel >= 1 else { return 0 }
        return min(1, travel / extraRow)
    }

    static func reducedProgress(offset: CGFloat, extent: CGFloat) -> CGFloat? {
        let overflow = max(0, extent - extraRow)
        guard overflow >= overflowThreshold else { return 0 }
        if offset <= restoreThreshold { return 0 }
        if offset >= overflowThreshold { return 1 }
        return nil
    }

    static func canFold(extent: CGFloat) -> Bool {
        max(0, extent - extraRow) >= overflowThreshold
    }
}

/// Header-only fold state so scrolling does not rebuild the measurement face.
@Observable @MainActor
final class InstrumentHeaderFold {
    var progress: CGFloat = 0
    var canFold = false
    private var compactSettled = false

    var collapsed: Bool { compactSettled }

    func reset() {
        progress = 0
        canFold = false
        compactSettled = false
    }

    func apply(_ sample: InstrumentHeaderScrollSample, reduceMotion: Bool) {
        let nextCanFold = canFold
            ? sample.overflow >= InstrumentHeaderMetrics.overflowThreshold - 16
            : sample.canFold
        if canFold != nextCanFold {
            canFold = nextCanFold
        }
        if reduceMotion {
            if let snapped = sample.reducedProgress, snapped != progress {
                progress = snapped
            }
        } else if abs(sample.progress - progress) > 0.02 {
            progress = sample.progress
        }
        let settled = progress >= 0.92 ? true : progress <= 0.12 ? false : compactSettled
        if compactSettled != settled {
            compactSettled = settled
        }
    }
}

struct InstrumentHeaderScrollSample: Equatable {
    var progress: CGFloat
    var reducedProgress: CGFloat?
    var overflow: CGFloat
    var canFold: Bool

    init(progress: CGFloat, reducedProgress: CGFloat?, canFold: Bool) {
        self.progress = progress
        self.reducedProgress = reducedProgress
        overflow = canFold ? InstrumentHeaderMetrics.overflowThreshold : 0
        self.canFold = canFold
    }

    init(_ geometry: ScrollGeometry) {
        let extent = max(0, geometry.contentSize.height + geometry.contentInsets.top
                         + geometry.contentInsets.bottom - geometry.containerSize.height)
        let offset = min(extent, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
        overflow = max(0, extent - InstrumentHeaderMetrics.extraRow)
        progress = InstrumentHeaderMetrics.progress(offset: offset, extent: extent)
        reducedProgress = InstrumentHeaderMetrics.reducedProgress(offset: offset, extent: extent)
        canFold = InstrumentHeaderMetrics.canFold(extent: extent)
    }
}

/// Keeps the same four controls alive while the source group folds into one row.
struct InstrumentHeaderLayout: Layout {
    var collapseProgress: CGFloat
    var stacked: Bool
    var maximumCompactWidth: CGFloat?

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

/// Observes fold progress so Home's measurement column is not invalidated per pixel.
struct InstrumentHeaderSurface<Content: View>: View {
    var fold: InstrumentHeaderFold
    var stacked: Bool
    var maximumCompactWidth: CGFloat?
    @ViewBuilder var content: (_ progress: CGFloat) -> Content

    var body: some View {
        let progress = stacked ? 0 : fold.progress
        let radius = 24 + 4 * progress
        content(progress)
            .background(ProTheme.face, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if !stacked {
                    GeometryReader { geometry in
                        Path { path in
                            let middle = geometry.size.height / 2
                            path.move(to: CGPoint(x: 16, y: middle))
                            path.addLine(to: CGPoint(x: geometry.size.width - 16, y: middle))
                            path.move(to: CGPoint(x: geometry.size.width / 2, y: 16))
                            path.addLine(to: CGPoint(x: geometry.size.width / 2, y: middle - 16))
                            path.move(to: CGPoint(x: geometry.size.width - 60, y: middle + 16))
                            path.addLine(to: CGPoint(x: geometry.size.width - 60, y: geometry.size.height - 16))
                        }.stroke(.primary.opacity(0.14), lineWidth: 0.5)
                    }
                    .opacity(Double(max(0, 1 - progress * 2)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Source controls")
            .accessibilityIdentifier("instrument.header")
            .accessibilityValue(fold.collapsed ? "Compact" : "Expanded")
    }
}

/// Observes only `canFold`, so scroll ticks do not rebuild Home's measurement column.
struct InstrumentHeaderScrollSpacer: View {
    var fold: InstrumentHeaderFold
    var stacked: Bool

    var body: some View {
        if !stacked, fold.canFold {
            Color.clear.frame(height: InstrumentHeaderMetrics.extraRow).accessibilityHidden(true)
        }
    }
}

struct InstrumentHeaderTopGutter: View {
    var fold: InstrumentHeaderFold
    var stacked: Bool

    var body: some View {
        if !stacked {
            Color.clear
                .frame(height: InstrumentHeaderMetrics.compactChrome + (fold.canFold ? 0 : InstrumentHeaderMetrics.extraRow))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }
}
