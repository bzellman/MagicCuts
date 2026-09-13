import SwiftUI

/// The scene is the working surface. Its controls remain reachable without hiding
/// the camera behind a second entry action or a full-screen settings panel.
struct SpatialInstrumentStage<Controls: View>: View {
    let session: RoomSession
    var showObservedMesh = false
    @ViewBuilder var controls: () -> Controls
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        GeometryReader { geometry in
            if sizeClass == .regular && !dynamicType.isAccessibilitySize {
                HStack(spacing: 0) {
                    scene
                    ScrollView { controls().padding(24) }
                        .frame(width: 360)
                        .background(ProTheme.face)
                }
            } else {
                scene
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        ScrollView { controls().padding(20) }
                            .frame(maxHeight: max(260, geometry.size.height * (dynamicType.isAccessibilitySize ? 0.58 : 0.48)))
                            .background(ProTheme.face, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                    }
            }
        }
        .background(MC.canvas)
    }

    private var scene: some View {
        ZStack {
            if session.cameraActive {
                RoomCameraView(session: session, showObservedMesh: showObservedMesh)
                    .accessibilityLabel("Live measurement camera")
                    .accessibilityIdentifier("spatial.camera")
                Image(systemName: "plus")
                    .font(.title.weight(.light))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            } else {
                VStack(spacing: 14) {
                    if session.phase == .preparing {
                        ProgressView("Opening camera…")
                    } else {
                        Image(systemName: "viewfinder").font(.largeTitle).foregroundStyle(ProTheme.secondary)
                        Text(session.phase == .unavailable ? "Camera unavailable" : session.phase.title)
                            .font(.headline)
                        Text(session.failure ?? session.instruction)
                            .font(.callout).foregroundStyle(ProTheme.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24).frame(maxWidth: 520)
                .accessibilityIdentifier("spatial.camera-status")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
