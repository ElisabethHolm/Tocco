import ARKit
import Foundation
import RealityKit
import simd

final class TouchSculptController {
    private weak var arView: ARView?
    private weak var appState: AppState?
    private weak var sculptEngine: SculptEngine?
    private weak var commandStack: CommandStack?
    /// Clay mesh entity — brush operates in its model-local space.
    weak var sculptTarget: ModelEntity?

    init(
        arView: ARView,
        appState: AppState,
        sculptEngine: SculptEngine,
        commandStack: CommandStack
    ) {
        self.arView = arView
        self.appState = appState
        self.sculptEngine = sculptEngine
        self.commandStack = commandStack
    }

    func sculpt(at location: CGPoint) {
        guard
            let arView,
            let appState,
            let sculptEngine,
            let target = sculptTarget
        else {
            ToccoDebug.throttled("sculpt-nil-deps", interval: 2, category: "Input", "sculpt(at:) skipped — missing arView, appState, sculptEngine, or sculptTarget")
            return
        }

        if appState.showAimAssist {
            let hitsClay = ClayScreenRay.screenAimHitsClay(
                screenPoint: location,
                arView: arView,
                modelEntity: target
            )
            let sz = arView.bounds.size
            let poly = AimRayProjection.screenRayPolyline(screenPoint: location, arView: arView)
            let norm: (CGPoint) -> CGPoint = { pt in
                CGPoint(x: pt.x / max(sz.width, 1), y: pt.y / max(sz.height, 1))
            }
            DispatchQueue.main.async {
                appState.aimReticleUV = norm(location)
                appState.aimReticleHitsClay = hitsClay
                appState.aimRayPolylineUV = poly.map(norm)
            }
        }

        guard let ray = ClayScreenRay.worldRay(from: location, arView: arView) else {
            ToccoDebug.throttled("sculpt-no-ray", interval: 1, category: "Input", "Could not build camera ray (no AR frame yet)")
            return
        }

        if let localCenter = ClayScreenRay.modelBrushPointOnClay(
            worldOrigin: ray.origin,
            worldDirection: ray.direction,
            modelEntity: target
        ) {
            let localRadius = ClayScreenRay.localBrushRadius(worldMeters: appState.brushSize, modelEntity: target)

            ToccoDebug.throttled(
                "clay-hit",
                interval: 0.35,
                category: "Input",
                "Clay ray hit local=(\(String(format: "%.2f", localCenter.x)),\(String(format: "%.2f", localCenter.y)),\(String(format: "%.2f", localCenter.z))) r_local=\(String(format: "%.3f", localRadius)) tool=\(appState.selectedTool)"
            )

            sculptEngine.applyBrush(
                center: localCenter,
                radius: localRadius,
                strength: appState.brushStrength,
                tool: appState.selectedTool,
                commandStack: commandStack
            )
            return
        }

        ToccoDebug.throttled(
            "clay-miss",
            interval: 0.7,
            category: "Input",
            "Ray missed clay sphere — aim pinch/touch at the gray ball (screen \(Int(location.x)),\(Int(location.y)))."
        )
    }
}
