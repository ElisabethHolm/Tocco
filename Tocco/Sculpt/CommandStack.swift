import Combine
import Foundation
import simd

struct SculptCommand {
    let indices: [Int]
    let before: [SIMD3<Float>]
    let after: [SIMD3<Float>]
}

final class CommandStack: ObservableObject {
    private var undoStack: [SculptCommand] = []
    private var redoStack: [SculptCommand] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func record(_ command: SculptCommand) {
        undoStack.append(command)
        redoStack.removeAll()
    }

    func undo(on meshData: inout MeshData) {
        guard let command = undoStack.popLast() else { return }
        apply(command.indices, command.before, to: &meshData)
        redoStack.append(command)
    }

    func redo(on meshData: inout MeshData) {
        guard let command = redoStack.popLast() else { return }
        apply(command.indices, command.after, to: &meshData)
        undoStack.append(command)
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private func apply(_ indices: [Int], _ values: [SIMD3<Float>], to meshData: inout MeshData) {
        guard indices.count == values.count else { return }
        for (idx, vertexIndex) in indices.enumerated() where meshData.vertices.indices.contains(vertexIndex) {
            meshData.vertices[vertexIndex] = values[idx]
        }
    }
}
