import SwiftUI

private func aimUVToScreen(_ uv: CGPoint, size: CGSize) -> CGPoint {
    CGPoint(x: uv.x * size.width, y: uv.y * size.height)
}

/// Thumb / index markers and hit reticle (green on clay, red off).
struct AimAssistOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geo in
            let viewport = appState.overlayViewportSize
            let size = viewport.width > 1 && viewport.height > 1 ? viewport : geo.size

            ZStack {
                if appState.showAimAssist {
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
