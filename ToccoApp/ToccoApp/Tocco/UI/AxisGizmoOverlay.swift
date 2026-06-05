import ARKit
import RealityKit
import SwiftUI

/// Screen-space X/Y/Z labels pinned to the 3D axis tips in move mode.
struct AxisGizmoOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geo in
            if appState.mode == .navigate {
                ForEach(appState.axisGizmoLabels) { label in
                    Text(label.text)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(label.color.opacity(0.92), in: Capsule())
                        .position(
                            x: label.uv.x * geo.size.width,
                            y: label.uv.y * geo.size.height
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct AxisGizmoLabel: Identifiable, Equatable {
    let id: String
    let text: String
    let uv: CGPoint
    let color: Color
}
