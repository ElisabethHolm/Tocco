import Combine
import Foundation

struct ToccoSession: Codable {
    let meshData: MeshData
    let date: Date
}

final class SessionStore: ObservableObject {
    private let fileName = "tocco_session.json"

    func save(meshData: MeshData) throws {
        ToccoDebug.info("Session", "save() → \(sessionURL.path) (\(meshData.vertices.count) vertices)")
        let session = ToccoSession(meshData: meshData, date: Date())
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionURL, options: .atomic)
        ToccoDebug.info("Session", "save() finished OK (\(data.count) bytes)")
    }

    func load() throws -> MeshData {
        ToccoDebug.info("Session", "load() ← \(sessionURL.path)")
        let data = try Data(contentsOf: sessionURL)
        let mesh = try JSONDecoder().decode(ToccoSession.self, from: data).meshData
        ToccoDebug.info("Session", "load() OK — \(mesh.vertices.count) vertices")
        return mesh
    }

    private var sessionURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(fileName)
    }
}
