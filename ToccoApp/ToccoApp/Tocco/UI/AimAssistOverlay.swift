import SwiftUI

private func aimUVToScreen(_ uv: CGPoint, size: CGSize) -> CGPoint {
    CGPoint(x: uv.x * size.width, y: uv.y * size.height)
}

/// Thumb / index markers, camera-ray polyline with arrow, and hit reticle (green on clay, red off).
struct AimAssistOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let rayColor = appState.aimReticleHitsClay ? Color.green : Color.red

            ZStack {
                if appState.showAimAssist {
                    AimRayPolylineShape(polylineUV: appState.aimRayPolylineUV, size: size, color: rayColor)

                    if appState.useHandGestures {
                        if let uv = appState.thumbTipUV {
                            FingerDotLabel(uv: uv, size: size, label: "T", fill: Color.orange)
                        }
                        if let uv = appState.indexTipUV {
                            FingerDotLabel(uv: uv, size: size, label: "I", fill: Color.blue)
                        }
                    }

                    if let uv = appState.aimReticleUV {
                        let p = aimUVToScreen(uv, size: size)
                        let onClay = appState.aimReticleHitsClay
                        Circle()
                            .strokeBorder(onClay ? Color.green : Color.red, lineWidth: 3)
                            .background(Circle().fill(Color.black.opacity(0.15)))
                            .frame(width: 44, height: 44)
                            .position(p)
                        Circle()
                            .fill(onClay ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                            .frame(width: 8, height: 8)
                            .position(p)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct FingerDotLabel: View {
    let uv: CGPoint
    let size: CGSize
    let label: String
    let fill: Color

    var body: some View {
        let p = aimUVToScreen(uv, size: size)
        ZStack {
            Circle()
                .fill(fill.opacity(0.95))
                .frame(width: 24, height: 24)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
        .position(p)
    }
}

private struct AimRayPolylineShape: View {
    let polylineUV: [CGPoint]
    let size: CGSize
    let color: Color

    var body: some View {
        let pts = polylineUV.map { aimUVToScreen($0, size: size) }
        ZStack {
            if pts.count >= 2 {
                Path { path in
                    path.move(to: pts[0])
                    for i in 1..<pts.count {
                        path.addLine(to: pts[i])
                    }
                }
                .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                if let tri = Self.arrowHead(from: pts) {
                    Path { path in
                        path.move(to: tri.0)
                        path.addLine(to: tri.1)
                        path.addLine(to: tri.2)
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.95))
                }
            }
        }
    }

    /// Arrow tip at last sample, pointing along the ray into the scene (along the polyline).
    private static func arrowHead(from pts: [CGPoint]) -> (CGPoint, CGPoint, CGPoint)? {
        guard pts.count >= 2 else { return nil }
        let tip = pts[pts.count - 1]
        let prev = pts[pts.count - 2]
        var vx = tip.x - prev.x
        var vy = tip.y - prev.y
        let len = hypot(vx, vy)
        guard len > 1 else { return nil }
        vx /= len
        vy /= len
        let arrowLen: CGFloat = 18
        let arrowW: CGFloat = 12
        let base = CGPoint(x: tip.x - vx * arrowLen, y: tip.y - vy * arrowLen)
        let px = -vy
        let py = vx
        let left = CGPoint(x: base.x + px * arrowW * 0.5, y: base.y + py * arrowW * 0.5)
        let right = CGPoint(x: base.x - px * arrowW * 0.5, y: base.y - py * arrowW * 0.5)
        return (left, tip, right)
    }
}
