import ARKit
import RealityKit
import simd
import UIKit

/// Screen ray vs clay sphere in **model space** (matches `MeshData` vertex coordinates).
enum ClayScreenRay {
    /// Default sphere radius in `MeshData.unitSphere(...)` — keep in sync.
    static let clayMeshRadius: Float = 0.12
    /// Wider test radius; brush is snapped to `clayMeshRadius` surface so sculpt stays on the real mesh.
    private static let clayAimSlopScale: Float = 1.75

    /// World-space ray from camera through a screen point.
    static func worldRay(from screenPoint: CGPoint, arView: ARView) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard let frame = arView.session.currentFrame else { return nil }
        let camera = frame.camera
        let size = arView.bounds.size
        guard size.width > 1, size.height > 1 else { return nil }

        let x = Float(2 * screenPoint.x / size.width - 1)
        let y = Float(-(2 * screenPoint.y / size.height - 1))

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let proj = camera.projectionMatrix(for: orientation, viewportSize: size, zNear: 0.001, zFar: 100)
        let view = camera.viewMatrix(for: orientation)
        let invVP = simd_inverse(proj * view)

        let nearH = invVP * SIMD4<Float>(x, y, 0, 1)
        let farH = invVP * SIMD4<Float>(x, y, 1, 1)
        let nearW = SIMD3<Float>(nearH.x, nearH.y, nearH.z) / nearH.w
        let farW = SIMD3<Float>(farH.x, farH.y, farH.z) / farH.w
        let dir = simd_normalize(farW - nearW)
        return (nearW, dir)
    }

    /// First intersection of the ray with a sphere at the model origin (unscaled mesh space).
    static func modelBrushPointOnClay(
        worldOrigin: SIMD3<Float>,
        worldDirection: SIMD3<Float>,
        modelEntity: ModelEntity
    ) -> SIMD3<Float>? {
        let u = simd_normalize(worldDirection)
        let worldFromModel = modelEntity.transformMatrix(relativeTo: nil)
        let modelFromWorld = worldFromModel.inverse
        let o4 = modelFromWorld * SIMD4<Float>(worldOrigin.x, worldOrigin.y, worldOrigin.z, 1)
        let o = SIMD3<Float>(o4.x, o4.y, o4.z) / o4.w
        let d4 = modelFromWorld * SIMD4<Float>(u.x, u.y, u.z, 0)
        let d = simd_normalize(SIMD3<Float>(d4.x, d4.y, d4.z))

        if let t = nearestPositiveRaySphereT(origin: o, dir: d, center: .zero, radius: clayMeshRadius) {
            return o + d * t
        }
        // Forgiving “fat” hit: if the ray passes near the clay, snap the brush to the real sphere surface.
        let fatR = clayMeshRadius * clayAimSlopScale
        if let t = nearestPositiveRaySphereT(origin: o, dir: d, center: .zero, radius: fatR) {
            let raw = o + d * t
            let len2 = simd_length_squared(raw)
            if len2 < 1e-8 { return SIMD3<Float>(0, 0, clayMeshRadius) }
            return simd_normalize(raw) * clayMeshRadius
        }
        return nil
    }

    /// Whether a screen point’s camera ray would hit the clay (tight or fat sphere), for UI reticle.
    static func screenAimHitsClay(
        screenPoint: CGPoint,
        arView: ARView,
        modelEntity: ModelEntity
    ) -> Bool {
        guard let ray = worldRay(from: screenPoint, arView: arView) else { return false }
        return modelBrushPointOnClay(
            worldOrigin: ray.origin,
            worldDirection: ray.direction,
            modelEntity: modelEntity
        ) != nil
    }

    /// Brush radius in model space (mesh vertices are unscaled; entity scale is applied in rendering).
    static func localBrushRadius(worldMeters: Float, modelEntity: ModelEntity) -> Float {
        let s = (modelEntity.scale.x + modelEntity.scale.y + modelEntity.scale.z) / 3
        guard s > 1e-4 else { return worldMeters }
        return worldMeters / s
    }

    private static func nearestPositiveRaySphereT(
        origin: SIMD3<Float>,
        dir: SIMD3<Float>,
        center: SIMD3<Float>,
        radius: Float
    ) -> Float? {
        let oc = origin - center
        let a = simd_dot(dir, dir)
        let b = 2 * simd_dot(oc, dir)
        let c = simd_dot(oc, oc) - radius * radius
        let disc = b * b - 4 * a * c
        guard disc >= 0 else { return nil }
        let sd = sqrt(disc)
        let t0 = (-b - sd) / (2 * a)
        let t1 = (-b + sd) / (2 * a)
        let candidates = [t0, t1].filter { $0 > 1e-4 }
        return candidates.min()
    }
}
