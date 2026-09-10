import SwiftUI
import simd

struct SurfaceEvidenceView: View {
    let surface: SurfaceFit
    private var coordinates: [(x: Float, y: Float, residual: Float)] {
        let n = surface.normal.simd
        let horizontal = simd_normalize(simd_cross(abs(n.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1), n))
        let vertical = simd_cross(n, horizontal)
        return surface.points.map {
            let delta = $0.simd - surface.center.simd
            return (simd_dot(delta, horizontal), simd_dot(delta, vertical), simd_dot(delta, n))
        }
    }
    var body: some View {
        let values = coordinates
        let width = max(0.001, values.map { abs($0.x) }.max() ?? 0)
        let height = max(0.001, values.map { abs($0.y) }.max() ?? 0)
        let residual = max(0.0001, values.map { abs($0.residual) }.max() ?? 0)
        VStack(alignment: .leading, spacing: 10) {
            Text("Observed surface patch").font(.headline)
            Canvas { context, size in
                let scale = Float(min(size.width, size.height)) * 0.42 / max(width, height)
                for value in values {
                    let intensity = Double(min(1, abs(value.residual) / residual))
                    let color = (value.residual < 0 ? Color.blue : Color.orange).opacity(0.25 + intensity * 0.75)
                    let p = CGPoint(x: size.width / 2 + Double(value.x * scale), y: size.height / 2 - Double(value.y * scale))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(color))
                }
            }.frame(height: 220).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(surface.count) depth points. Patch extent \((width * 2).formatted(.number.precision(.fractionLength(2)))) by \((height * 2).formatted(.number.precision(.fractionLength(2)))) meters. Residual RMS \((surface.rmsMeters * 1000).formatted(.number.precision(.fractionLength(1)))) millimeters.")
            Text("Blue: below plane · Orange: above plane · Scale: ±\((residual * 1000).formatted(.number.precision(.fractionLength(1)))) mm").font(.caption).foregroundStyle(ProTheme.secondary)
            Text("\((width * 2).formatted(.number.precision(.fractionLength(2)))) × \((height * 2).formatted(.number.precision(.fractionLength(2)))) m sampled extent. Points are shown in the fitted plane's local axes. Sensor noise contributes to every residual.").font(.caption).foregroundStyle(ProTheme.secondary)
        }
    }
}
