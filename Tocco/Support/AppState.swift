import Combine
import CoreGraphics
import Foundation
import simd

final class AppState: ObservableObject {
    @Published var selectedTool: SculptTool = .pull
    @Published var brushSize: Float = 0.06
    @Published var brushStrength: Float = 0.025
    @Published var mode: InteractionMode = .sculpt
    @Published var useHandGestures = false
    @Published var modelScale: Float = 1.0
    @Published var modelRotationY: Float = 0.0
    @Published var modelYOffset: Float = 0.0
    @Published var performanceSample = PerformanceSample(frameTimeMS: 0, vertexCount: 0, brushTimeMS: 0)
    @Published var statusText = "Ready"
    @Published var toolPanelExpanded = true
    @Published var performancePanelExpanded = false
    @Published var showAimAssist = true
    /// Normalized to ARView bounds (0…1), top-left origin — matches SwiftUI overlay when both fill the window.
    @Published var aimReticleUV: CGPoint?
    @Published var aimReticleHitsClay = false
    @Published var thumbTipUV: CGPoint?
    @Published var indexTipUV: CGPoint?
    /// Normalized polyline for the camera ray through the aim point (for drawing on overlay).
    @Published var aimRayPolylineUV: [CGPoint] = []

    var lastHandShortcutGesture: HandGestureRecognizer.Gesture = .none
    var lastPinchShortcutTimestamp: TimeInterval?
}

enum InteractionMode: String, CaseIterable, Identifiable {
    case sculpt
    case navigate

    var id: String { rawValue }
}

struct PerformanceSample: Equatable {
    let frameTimeMS: Double
    let vertexCount: Int
    let brushTimeMS: Double
}
