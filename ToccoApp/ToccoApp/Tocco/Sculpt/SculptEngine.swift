import Combine
import Foundation
import simd

final class SculptEngine: ObservableObject {
    @Published private(set) var meshData: MeshData = .unitSphere()
    @Published private(set) var lastBrushTimeMS: Double = 0
    private var adjacency: [[Int]] = []

    init() {
        rebuildAdjacency()
    }

    func resetMesh() {
        meshData = .unitSphere()
        rebuildAdjacency()
        ToccoDebug.info("Sculpt", "resetMesh — back to unit sphere (\(meshData.vertices.count) vertices)")
    }

    func applyBrush(
        center: SIMD3<Float>,
        radius: Float,
        strength: Float,
        tool: SculptTool,
        commandStack: CommandStack?
    ) {
        guard radius > 0, strength > 0 else {
            ToccoDebug.throttled("brush-bad-params", interval: 1.0, category: "Sculpt", "applyBrush skipped — radius or strength must be > 0 (r=\(radius), s=\(strength))")
            return
        }

        var touchedIndices: [Int] = []
        var beforePositions: [SIMD3<Float>] = []
        var afterPositions: [SIMD3<Float>] = []

        lastBrushTimeMS = SculptProfiler.measure {
            for index in meshData.vertices.indices {
                let vertex = meshData.vertices[index]
                let distance = simd_length(vertex - center)
                guard distance < radius else { continue }

                let falloff = BrushKernels.smoothFalloff(distance: distance, radius: radius)

                if tool == .smooth {
                    let normal = simd_normalize(meshData.normals[index])
                    let projected = center + normal * simd_dot(vertex - center, normal)
                    let smoothed = simd_mix(vertex, projected, SIMD3<Float>(repeating: 0.08 * falloff))
                    touchedIndices.append(index)
                    beforePositions.append(vertex)
                    afterPositions.append(smoothed)
                    meshData.vertices[index] = smoothed
                } else {
                    let normal = safeNormal(at: index)
                    let delta = BrushKernels.displacement(
                        tool: tool,
                        normal: normal,
                        falloff: falloff,
                        strength: strength
                    )
                    let next = vertex + delta
                    touchedIndices.append(index)
                    beforePositions.append(vertex)
                    afterPositions.append(next)
                    meshData.vertices[index] = next
                }
            }
            recomputeNormals(localTo: touchedIndices)
        }

        if touchedIndices.isEmpty {
            ToccoDebug.throttled(
                "brush-no-verts",
                interval: 0.7,
                category: "Sculpt",
                "applyBrush: 0 vertices in radius — brush center may be far from clay mesh (coordinate mismatch or tiny brush). center=\(center), r=\(radius), tool=\(tool)"
            )
        } else {
            ToccoDebug.throttled(
                "brush-ok",
                interval: 0.4,
                category: "Sculpt",
                "applyBrush OK — \(touchedIndices.count) verts, tool=\(tool), \(String(format: "%.2f", lastBrushTimeMS)) ms"
            )
            let command = SculptCommand(indices: touchedIndices, before: beforePositions, after: afterPositions)
            commandStack?.record(command)
        }
    }

    func restore(meshData: MeshData) {
        self.meshData = meshData
        rebuildAdjacency()
        ToccoDebug.info("Sculpt", "restore(meshData:) — \(meshData.vertices.count) vertices")
    }

    private func safeNormal(at index: Int) -> SIMD3<Float> {
        guard meshData.normals.indices.contains(index) else { return SIMD3<Float>(0, 1, 0) }
        let normal = meshData.normals[index]
        if simd_length_squared(normal) < 0.0001 {
            return SIMD3<Float>(0, 1, 0)
        }
        return simd_normalize(normal)
    }

    private func recomputeNormals(localTo touched: [Int]) {
        if meshData.normals.count != meshData.vertices.count {
            meshData.normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: meshData.vertices.count)
        }

        let localSet = Set(touched.flatMap { [ $0 ] + (adjacency.indices.contains($0) ? adjacency[$0] : []) })
        guard !localSet.isEmpty else { return }

        for vertexIndex in localSet where meshData.vertices.indices.contains(vertexIndex) {
            var acc = SIMD3<Float>(repeating: 0)
            let triCount = meshData.indices.count / 3
            for tri in 0..<triCount {
                let a = Int(meshData.indices[tri * 3])
                let b = Int(meshData.indices[tri * 3 + 1])
                let c = Int(meshData.indices[tri * 3 + 2])
                guard a == vertexIndex || b == vertexIndex || c == vertexIndex else { continue }
                guard
                    meshData.vertices.indices.contains(a),
                    meshData.vertices.indices.contains(b),
                    meshData.vertices.indices.contains(c)
                else { continue }
                let va = meshData.vertices[a]
                let vb = meshData.vertices[b]
                let vc = meshData.vertices[c]
                acc += simd_cross(vb - va, vc - va)
            }

            if simd_length_squared(acc) < 0.0001 {
                meshData.normals[vertexIndex] = SIMD3<Float>(0, 1, 0)
            } else {
                meshData.normals[vertexIndex] = simd_normalize(acc)
            }
        }
    }

    private func rebuildAdjacency() {
        adjacency = MeshNeighborhood.buildAdjacency(
            indices: meshData.indices,
            vertexCount: meshData.vertices.count
        )
    }
}
