import ARKit
import CoreGraphics
import RealityKit
import simd

/// Projects world-space samples along the sculpt ray into ARView screen coordinates (matches `ClayScreenRay.worldRay`).
enum AimRayProjection {
    static func screenRayPolyline(
        screenPoint: CGPoint,
        arView: ARView,
        maxDistanceMeters: Float = 2.0,
        steps: Int = 36
    ) -> [CGPoint] {
        guard let frame = arView.session.currentFrame else { return [] }
        guard let ray = ClayScreenRay.worldRay(from: screenPoint, arView: arView) else { return [] }
        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let viewport = arView.bounds.size
        guard viewport.width > 1, viewport.height > 1 else { return [] }

        let count = max(3, steps)
        let step = maxDistanceMeters / Float(count - 1)
        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        for i in 0..<count {
            let t = Float(i) * step
            let world = ray.origin + ray.direction * t
            let screen = frame.camera.projectPoint(world, orientation: orientation, viewportSize: viewport)
            pts.append(screen)
        }
        return pts
    }
}
