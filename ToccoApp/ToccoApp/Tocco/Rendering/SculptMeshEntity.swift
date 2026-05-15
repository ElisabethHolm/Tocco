import Foundation
import RealityKit
import UIKit
import simd

final class SculptMeshEntity {
    let modelEntity = ModelEntity()

    init(meshData: MeshData) {
        update(meshData: meshData)
    }

    func update(meshData: MeshData) {
        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffer(meshData.vertices)
        descriptor.normals = MeshBuffer(meshData.normals)
        descriptor.primitives = .triangles(meshData.indices)

        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            let material = SimpleMaterial(color: .init(white: 0.88, alpha: 1), roughness: 0.6, isMetallic: false)
            modelEntity.model = ModelComponent(mesh: mesh, materials: [material])
        } catch {
            ToccoDebug.error("Mesh", "MeshResource.generate failed: \(error.localizedDescription)")
            assertionFailure("Mesh generation failed: \(error.localizedDescription)")
        }
    }
}
