import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

@main
struct MagicCutsLiveSessionBundle: WidgetBundle {
    var body: some Widget { MagicCutsLiveSessionWidget() }
}

struct MagicCutsLiveSessionWidget: Widget {
    private let blue = Color(red: 0.38, green: 0.72, blue: 1)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(context.attributes.instrument, systemImage: context.attributes.symbol).font(.system(.headline, design: .rounded)).foregroundStyle(blue)
                    Spacer()
                    Text("MagicCuts Pro").font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(context.state.value).font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                    Text(context.state.unit).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(context.state.sampleCount) readings").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.isStale ? "Waiting for a current reading" : context.state.status).font(.caption)
                        Text(context.attributes.source).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let date = context.state.readingDate { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                }
            }
            .padding(18)
            .activityBackgroundTint(Color(red: 0.04, green: 0.06, blue: 0.075))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(URL(string: "magiccuts://session/\(context.attributes.sessionID.uuidString)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.instrument, systemImage: context.attributes.symbol).font(.system(.headline, design: .rounded)).foregroundStyle(blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.sampleCount)").font(.system(.headline, design: .rounded)).monospacedDigit().accessibilityLabel("\(context.state.sampleCount) readings")
                }
                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(context.state.value).font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text(context.state.unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? "Waiting for a current reading" : context.state.status).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol).foregroundStyle(blue)
            } compactTrailing: {
                Text(context.state.value).font(.system(.caption, design: .rounded).weight(.semibold)).monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.symbol).foregroundStyle(blue)
            }
            .widgetURL(URL(string: "magiccuts://session/\(context.attributes.sessionID.uuidString)"))
            .keylineTint(blue)
        }
    }
}
