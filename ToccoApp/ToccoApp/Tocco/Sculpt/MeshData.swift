import Foundation
import simd

struct MeshData: Codable {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]

    static func unitSphere(samples: Int = 20, radius: Float = 0.12) -> MeshData {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        let latCount = max(samples, 8)
        let lonCount = max(samples * 2, 16)

        for lat in 0...latCount {
            let theta = Float(lat) / Float(latCount) * .pi
            for lon in 0...lonCount {
                let phi = Float(lon) / Float(lonCount) * (2 * .pi)
                let x = sin(theta) * cos(phi)
                let y = cos(theta)
                let z = sin(theta) * sin(phi)
                let normal = SIMD3<Float>(x, y, z)
                vertices.append(normal * radius)
                normals.append(simd_normalize(normal))
            }
        }

        let row = lonCount + 1
        for lat in 0..<latCount {
            for lon in 0..<lonCount {
                let a = UInt32(lat * row + lon)
                let b = UInt32((lat + 1) * row + lon)
                let c = UInt32((lat + 1) * row + lon + 1)
                let d = UInt32(lat * row + lon + 1)
                indices += [a, b, d, b, c, d]
            }
        }

        return MeshData(vertices: vertices, normals: normals, indices: indices)
    }
}
