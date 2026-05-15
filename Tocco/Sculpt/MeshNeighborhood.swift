import Foundation

struct MeshNeighborhood {
    static func buildAdjacency(indices: [UInt32], vertexCount: Int) -> [[Int]] {
        var adjacency = Array(repeating: Set<Int>(), count: vertexCount)
        let triCount = indices.count / 3

        for t in 0..<triCount {
            let a = Int(indices[t * 3])
            let b = Int(indices[t * 3 + 1])
            let c = Int(indices[t * 3 + 2])
            guard a < vertexCount, b < vertexCount, c < vertexCount else { continue }
            adjacency[a].formUnion([b, c])
            adjacency[b].formUnion([a, c])
            adjacency[c].formUnion([a, b])
        }

        return adjacency.map { Array($0) }
    }
}
