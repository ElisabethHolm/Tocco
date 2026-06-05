import SwiftUI

private func uvToScreen(_ uv: CGPoint, size: CGSize) -> CGPoint {
    CGPoint(x: uv.x * size.width, y: uv.y * size.height)
}

/// MediaPipe-style hand skeleton debug overlay (bones + joint dots).
struct HandSkeletonOverlay: View {
    @EnvironmentObject private var appState: AppState

    private static let jointColors: [Color] = [
        .white,
        .orange, .orange, .orange, .orange,
        .blue, .blue, .blue, .blue,
        .green, .green, .green, .green,
        .yellow, .yellow, .yellow, .yellow,
        .purple, .purple, .purple, .purple,
    ]

    var body: some View {
        GeometryReader { geo in
            let viewport = appState.overlayViewportSize
            let size = viewport.width > 1 && viewport.height > 1 ? viewport : geo.size

            ZStack {
                if appState.showHandSkeletonOverlay {
                    ForEach(Array(appState.handSkeletonSegmentsUV.enumerated()), id: \.offset) { _, segment in
                        let start = uvToScreen(segment.0, size: size)
                        let end = uvToScreen(segment.1, size: size)
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(Color.cyan.opacity(0.95), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }

                    ForEach(Array(appState.handSkeletonJointUVs.enumerated()), id: \.offset) { index, uv in
                        let p = uvToScreen(uv, size: size)
                        let fill = Self.jointColors[min(index, Self.jointColors.count - 1)]
                        Circle()
                            .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                            .background(Circle().fill(fill.opacity(0.95)))
                            .frame(width: 10, height: 10)
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
