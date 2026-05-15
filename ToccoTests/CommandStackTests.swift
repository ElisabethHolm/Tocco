import XCTest
import simd
@testable import Tocco

final class CommandStackTests: XCTestCase {
    func testUndoRedoRestoresState() {
        let engine = SculptEngine()
        let stack = CommandStack()
        let original = engine.meshData

        engine.applyBrush(
            center: SIMD3<Float>(0, 0, 0),
            radius: 0.12,
            strength: 0.04,
            tool: .pull,
            commandStack: stack
        )

        var undoMesh = engine.meshData
        stack.undo(on: &undoMesh)
        XCTAssertEqual(undoMesh.vertices, original.vertices)

        stack.redo(on: &undoMesh)
        XCTAssertNotEqual(undoMesh.vertices, original.vertices)
    }

    func testUndoOnEmptyStackIsNoOp() {
        let stack = CommandStack()
        var mesh = MeshData.unitSphere(samples: 8, radius: 0.1)
        let original = mesh.vertices

        stack.undo(on: &mesh)
        XCTAssertEqual(mesh.vertices, original)
    }
}
