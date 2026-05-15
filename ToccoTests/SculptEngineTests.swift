import XCTest
import simd
@testable import Tocco

final class SculptEngineTests: XCTestCase {
    func testBrushChangesVerticesWithoutNaN() {
        let engine = SculptEngine()
        let stack = CommandStack()

        engine.applyBrush(
            center: SIMD3<Float>(0, 0, 0),
            radius: 0.1,
            strength: 0.03,
            tool: .pull,
            commandStack: stack
        )

        XCTAssertFalse(engine.meshData.vertices.isEmpty)
        for v in engine.meshData.vertices {
            XCTAssertFalse(v.x.isNaN || v.y.isNaN || v.z.isNaN)
        }
    }

    func testZeroRadiusDoesNotMutateMesh() {
        let engine = SculptEngine()
        let stack = CommandStack()
        let original = engine.meshData.vertices

        engine.applyBrush(
            center: SIMD3<Float>(0, 0, 0),
            radius: 0,
            strength: 0.03,
            tool: .pull,
            commandStack: stack
        )

        XCTAssertEqual(engine.meshData.vertices, original)
    }
}
