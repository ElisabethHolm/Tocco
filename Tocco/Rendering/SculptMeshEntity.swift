import Foundation
import RealityKit
import simd
import UIKit

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

        let textureCoordinates = meshData.vertices.map {
            ClaySurfaceColorizer.textureCoordinate(for: $0)
        }
        descriptor.textureCoordinates = MeshBuffer(textureCoordinates)

        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            let gradient = try ClaySurfaceColorizer.gradientTexture()
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: .white, texture: .init(gradient))
            material.roughness = .init(floatLiteral: 0.55)
            material.metallic = .init(floatLiteral: 0.0)
            modelEntity.model = ModelComponent(mesh: mesh, materials: [material])
            modelEntity.generateCollisionShapes(recursive: true)
        } catch {
            ToccoDebug.error("Mesh", "MeshResource.generate failed: \(error.localizedDescription)")
            assertionFailure("Mesh generation failed: \(error.localizedDescription)")
        }
    }
}
