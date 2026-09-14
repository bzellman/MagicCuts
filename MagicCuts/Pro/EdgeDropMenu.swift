import SwiftUI

/// Full-width working menu that hangs under Home chrome with the same edge inset.
struct EdgeDropMenu<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ProTheme.face, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("instrument.device-menu.panel")
    }
}

struct EdgeDropMenuRow: View {
    let title: String
    var detail: String?
    var symbol: String
    var selected = false
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(MC.action)
                    .frame(width: 28, height: 28)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(.headline, design: .rounded))
                    if let detail, !detail.isEmpty {
                        Text(detail).font(.callout).foregroundStyle(ProTheme.secondary)
                    }
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(MC.action)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(detail ?? "")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(identifier ?? "drop-menu.\(title)")
    }
}
