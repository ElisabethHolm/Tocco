import RealityKit
import UIKit
import simd

/// Move arrows + rotation rings shown while repositioning the clay piece.
final class TransformAxesGizmo {
    enum Axis: String, CaseIterable {
        case x, y, z

        var localDirection: SIMD3<Float> {
            switch self {
            case .x: return SIMD3(1, 0, 0)
            case .y: return SIMD3(0, 1, 0)
            case .z: return SIMD3(0, 0, 1)
            }
        }

        var color: UIColor {
            switch self {
            case .x: return .systemRed
            case .y: return .systemGreen
            case .z: return .systemBlue
            }
        }

        var moveLabel: String {
            switch self {
            case .x: return "X"
            case .y: return "Y"
            case .z: return "Z"
            }
        }

        var rotateLabel: String {
            switch self {
            case .x: return "↻X"
            case .y: return "↻Y"
            case .z: return "↻Z"
            }
        }
    }

    enum HandleKind: Equatable {
        case translate(Axis)
        case rotate(Axis)
    }

    private let root = Entity()
    private var axisEntities: [Axis: ModelEntity] = [:]
    private var ringSegments: [Axis: [ModelEntity]] = [:]
    private let axisLength: Float = 0.20
    private let axisThickness: Float = 0.007
    private let tipRadius: Float = 0.014
    private let ringRadius: Float = 0.27
    private let ringRodThickness: Float = 0.007
    private let ringSegmentCount = 56

    init() {
        root.name = "transformAxesGizmo"
        for axis in Axis.allCases {
            let shaft = makeShaft(axis: axis)
            let tip = makeTip(axis: axis)
            let ring = makeRodRotateRing(axis: axis)
            axisEntities[axis] = shaft
            ringSegments[axis] = ring
            root.addChild(shaft)
            root.addChild(tip)
            for segment in ring {
                root.addChild(segment)
            }
        }
    }

    func attach(to model: Entity) {
        guard root.parent == nil else { return }
        model.addChild(root)
    }

    func setVisible(_ visible: Bool) {
        root.isEnabled = visible
        if !visible {
            setSelected(nil)
        }
    }

    func handle(for entity: Entity) -> HandleKind? {
        var current: Entity? = entity
        while let node = current {
            if let axis = Axis(rawValue: node.name) {
                return .translate(axis)
            }
            if node.name.hasSuffix("_tip"),
               let prefix = node.name.split(separator: "_").first,
               let axis = Axis(rawValue: String(prefix)) {
                return .translate(axis)
            }
            if node.name.hasPrefix("ring_") {
                let parts = node.name.split(separator: "_")
                if parts.count >= 2, let axis = Axis(rawValue: String(parts[1])) {
                    return .rotate(axis)
                }
            }
            if node === root { break }
            current = node.parent
        }
        return nil
    }

    func setSelected(_ handle: HandleKind?) {
        for (axis, entity) in axisEntities {
            let selected = handle == .translate(axis)
            applyTint(to: entity, color: axis.color, selected: selected, solid: true)
            entity.scale = SIMD3(repeating: selected ? 1.2 : 1)
        }
        for (axis, segments) in ringSegments {
            let selected = handle == .rotate(axis)
            for segment in segments {
                applyTint(to: segment, color: axis.color, selected: selected, solid: true)
                segment.scale = SIMD3(repeating: selected ? 1.12 : 1)
            }
        }
    }

    func localDirection(for axis: Axis) -> SIMD3<Float> {
        axis.localDirection
    }

    func moveTipWorldPosition(for axis: Axis, on model: Entity) -> SIMD3<Float> {
        model.convert(position: axis.localDirection * axisLength, to: nil)
    }

    func rotateLabelWorldPosition(for axis: Axis, on model: Entity) -> SIMD3<Float> {
        let local: SIMD3<Float>
        switch axis {
        case .x: local = SIMD3(0, ringRadius, 0)
        case .y: local = SIMD3(ringRadius, 0, 0)
        case .z: local = SIMD3(ringRadius, 0, 0)
        }
        return model.convert(position: local, to: nil)
    }

    private func applyTint(to entity: ModelEntity, color: UIColor, selected: Bool, solid: Bool) {
        let alpha: CGFloat = solid ? (selected ? 1 : 0.72) : (selected ? 0.95 : 0.45)
        if var model = entity.model {
            model.materials = [SimpleMaterial(color: color.withAlphaComponent(alpha), roughness: 0.2, isMetallic: false)]
            entity.model = model
        }
    }

    private func makeShaft(axis: Axis) -> ModelEntity {
        let size: SIMD3<Float>
        let offset: SIMD3<Float>
        switch axis {
        case .x:
            size = SIMD3(axisLength, axisThickness, axisThickness)
            offset = SIMD3(axisLength * 0.5, 0, 0)
        case .y:
            size = SIMD3(axisThickness, axisLength, axisThickness)
            offset = SIMD3(0, axisLength * 0.5, 0)
        case .z:
            size = SIMD3(axisThickness, axisThickness, axisLength)
            offset = SIMD3(0, 0, axisLength * 0.5)
        }

        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: axis.color.withAlphaComponent(0.85), roughness: 0.25, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = axis.rawValue
        entity.position = offset
        entity.generateCollisionShapes(recursive: true)
        return entity
    }

    private func makeTip(axis: Axis) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: tipRadius)
        let material = SimpleMaterial(color: axis.color, roughness: 0.15, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "\(axis.rawValue)_tip"
        entity.position = axis.localDirection * axisLength
        entity.generateCollisionShapes(recursive: true)
        return entity
    }

    private func makeRodRotateRing(axis: Axis) -> [ModelEntity] {
        var segments: [ModelEntity] = []
        let circumference = 2 * Float.pi * ringRadius
        let segLength = (circumference / Float(ringSegmentCount)) * 1.04

        for index in 0..<ringSegmentCount {
            let angle = (Float(index) / Float(ringSegmentCount)) * 2 * .pi
            let mesh = MeshResource.generateBox(size: [segLength, ringRodThickness, ringRodThickness])
            let material = SimpleMaterial(color: axis.color.withAlphaComponent(0.72), roughness: 0.25, isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = "ring_\(axis.rawValue)_\(index)"

            switch axis {
            case .x:
                entity.position = SIMD3(0, cos(angle) * ringRadius, sin(angle) * ringRadius)
                entity.orientation = simd_quatf(angle: angle, axis: SIMD3(1, 0, 0))
            case .y:
                entity.position = SIMD3(cos(angle) * ringRadius, 0, sin(angle) * ringRadius)
                entity.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            case .z:
                entity.position = SIMD3(cos(angle) * ringRadius, sin(angle) * ringRadius, 0)
                entity.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 0, 1))
            }

            entity.generateCollisionShapes(recursive: true)
            segments.append(entity)
        }
        return segments
    }
}
