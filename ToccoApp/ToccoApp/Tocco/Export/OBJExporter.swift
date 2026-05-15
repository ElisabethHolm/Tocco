import Foundation

struct OBJExporter {
    @discardableResult
    func export(meshData: MeshData, fileName: String = "tocco_model.obj") throws -> URL {
        var lines: [String] = ["# Tocco OBJ export"]

        for v in meshData.vertices {
            lines.append("v \(v.x) \(v.y) \(v.z)")
        }
        for n in meshData.normals {
            lines.append("vn \(n.x) \(n.y) \(n.z)")
        }

        let triCount = meshData.indices.count / 3
        for t in 0..<triCount {
            let i0 = Int(meshData.indices[t * 3]) + 1
            let i1 = Int(meshData.indices[t * 3 + 1]) + 1
            let i2 = Int(meshData.indices[t * 3 + 2]) + 1
            lines.append("f \(i0)//\(i0) \(i1)//\(i1) \(i2)//\(i2)")
        }

        let content = lines.joined(separator: "\n")
        let url = documentsURL.appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        ToccoDebug.info("Export", "OBJ export OK — \(url.path) (\(meshData.vertices.count) v, \(triCount) tri)")
        return url
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
