import Foundation

struct GLTFExporter {
    // Minimal placeholder: writes mesh as JSON metadata for future glTF pipeline.
    // This keeps the API surface stable while OBJ remains the required export.
    @discardableResult
    func exportStub(meshData: MeshData, fileName: String = "tocco_model.gltf.json") throws -> URL {
        struct Payload: Codable {
            let vertexCount: Int
            let indexCount: Int
            let note: String
        }

        let payload = Payload(
            vertexCount: meshData.vertices.count,
            indexCount: meshData.indices.count,
            note: "Stub output. Replace with full glTF buffer + accessor export."
        )
        let data = try JSONEncoder().encode(payload)
        let url = documentsURL.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        ToccoDebug.info("Export", "glTF stub wrote \(url.path) (\(payload.vertexCount) verts metadata only)")
        return url
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
