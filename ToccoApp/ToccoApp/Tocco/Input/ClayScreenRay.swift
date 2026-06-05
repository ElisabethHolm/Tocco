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

    /// World-space ray from camera through a screen point in ARView coordinates.
    static func worldRay(from screenPoint: CGPoint, arView: ARView) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        arView.ray(through: screenPoint)
    }

    /// Brush center on the clay surface in model space, from a screen aim point.
    static func modelBrushPointOnClay(
        screenPoint: CGPoint,
        arView: ARView,
        modelEntity: ModelEntity
    ) -> SIMD3<Float>? {
        if let local = hitTestClayLocal(screenPoint: screenPoint, arView: arView, modelEntity: modelEntity) {
            return local
        }
        guard let ray = worldRay(from: screenPoint, arView: arView) else { return nil }
        return modelBrushPointOnClay(
            worldOrigin: ray.origin,
            worldDirection: ray.direction,
            modelEntity: modelEntity
        )
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
        let fatR = clayMeshRadius * clayAimSlopScale
        if let t = nearestPositiveRaySphereT(origin: o, dir: d, center: .zero, radius: fatR) {
            let raw = o + d * t
            let len2 = simd_length_squared(raw)
            if len2 < 1e-8 { return SIMD3<Float>(0, 0, clayMeshRadius) }
            return simd_normalize(raw) * clayMeshRadius
        }
        return nil
    }

    /// Whether a screen point’s camera ray would hit the clay (mesh hit-test or analytic sphere), for UI reticle.
    static func screenAimHitsClay(
        screenPoint: CGPoint,
        arView: ARView,
        modelEntity: ModelEntity
    ) -> Bool {
        modelBrushPointOnClay(screenPoint: screenPoint, arView: arView, modelEntity: modelEntity) != nil
    }

    /// Brush radius in model space (mesh vertices are unscaled; entity scale is applied in rendering).
    static func localBrushRadius(worldMeters: Float, modelEntity: ModelEntity) -> Float {
        let s = (modelEntity.scale.x + modelEntity.scale.y + modelEntity.scale.z) / 3
        guard s > 1e-4 else { return worldMeters }
        return worldMeters / s
    }

    private static func hitTestClayLocal(
        screenPoint: CGPoint,
        arView: ARView,
        modelEntity: ModelEntity
    ) -> SIMD3<Float>? {
        let hits = arView.hitTest(screenPoint, query: .nearest, mask: .all)
        for hit in hits where isClayMeshHit(hit.entity, clayRoot: modelEntity) {
            return worldToLocal(hit.position, modelEntity: modelEntity)
        }
        return nil
    }

    private static func isClayMeshHit(_ entity: Entity, clayRoot: ModelEntity) -> Bool {
        guard isDescendant(entity, of: clayRoot) else { return false }
        return !isGizmoEntity(entity)
    }

    private static func isGizmoEntity(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current {
            if node.name == "transformAxesGizmo" { return true }
            current = node.parent
        }
        return false
    }

    private static func isDescendant(_ entity: Entity, of root: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current {
            if node === root { return true }
            current = node.parent
        }
        return false
    }

    private static func worldToLocal(_ world: SIMD3<Float>, modelEntity: ModelEntity) -> SIMD3<Float> {
        let modelFromWorld = modelEntity.transformMatrix(relativeTo: nil).inverse
        let local4 = modelFromWorld * SIMD4<Float>(world.x, world.y, world.z, 1)
        return SIMD3<Float>(local4.x, local4.y, local4.z) / local4.w
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
