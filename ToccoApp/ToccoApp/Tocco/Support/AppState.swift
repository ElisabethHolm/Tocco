import Combine
import CoreGraphics
import Foundation
import simd

final class AppState: ObservableObject {
    @Published var selectedTool: SculptTool = .pull
    @Published var brushSize: Float = 0.06
    @Published var brushStrength: Float = 0.025
    @Published var mode: InteractionMode = .sculpt
    @Published var useHandGestures = true
    @Published var modelScale: Float = 1.0
    @Published var modelRotationY: Float = 0.0
    @Published var modelYOffset: Float = 0.0
    @Published var performanceSample = PerformanceSample(frameTimeMS: 0, vertexCount: 0, brushTimeMS: 0)
    @Published var statusText = "Ready"
    @Published private(set) var gestureToast: GestureToastBanner?
    @Published var toolPanelExpanded = true
    @Published var performancePanelExpanded = false
    @Published var showAimAssist = true
    @Published var showHandSkeletonOverlay = false
    @Published var showPersonSegmentationOverlay = false
    @Published var handSkeletonSegmentsUV: [(CGPoint, CGPoint)] = []
    @Published var handSkeletonJointUVs: [CGPoint] = []
    @Published var personSegmentationOverlayImage: CGImage?
    @Published var axisGizmoLabels: [AxisGizmoLabel] = []
    /// Normalized to ARView bounds (0…1), top-left origin — matches SwiftUI overlay when both fill the window.
    @Published var aimReticleUV: CGPoint?
    @Published var aimReticleHitsClay = false
    @Published var thumbTipUV: CGPoint?
    @Published var indexTipUV: CGPoint?
    /// ARView bounds in points — overlays use this so UVs match the camera view, not SwiftUI layout.
    @Published var overlayViewportSize: CGSize = .zero

    var lastHandShortcutGesture: HandGestureRecognizer.Gesture = .none
    var lastPinchShortcutTimestamp: TimeInterval?
    private var gestureToastDismissWorkItem: DispatchWorkItem?

    func presentGestureToast(_ message: String, symbol: String? = nil, duration: TimeInterval = 2.2) {
        gestureToastDismissWorkItem?.cancel()
        gestureToast = GestureToastBanner(message: message, symbol: symbol)
        let work = DispatchWorkItem { [weak self] in
            self?.gestureToast = nil
        }
        gestureToastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}

struct GestureToastBanner: Equatable {
    let message: String
    let symbol: String?
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
