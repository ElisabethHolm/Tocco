import Foundation
import simd

enum BrushKernels {
    static func linearFalloff(distance: Float, radius: Float) -> Float {
        guard radius > 0 else { return 0 }
        let t = max(0, min(1, 1 - (distance / radius)))
        return t
    }

    static func smoothFalloff(distance: Float, radius: Float) -> Float {
        let t = linearFalloff(distance: distance, radius: radius)
        return t * t * (3 - 2 * t)
    }

    static func displacement(
        tool: SculptTool,
        normal: SIMD3<Float>,
        falloff: Float,
        strength: Float
    ) -> SIMD3<Float> {
        switch tool {
        case .push:
            return -normal * (falloff * strength)
        case .pull:
            return normal * (falloff * strength)
        case .smooth:
            return .zero
        }
    }
}
