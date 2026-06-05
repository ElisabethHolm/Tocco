import CoreGraphics
import Foundation
import RealityKit
import simd

/// Maps vertex distance from the clay origin to surface colors (carve → neutral → bulge).
enum ClaySurfaceColorizer {
    /// Resting sphere radius from `MeshData.unitSphere`.
    static let baseRadius: Float = 0.12
    /// Deviation of this magnitude maps to the full carve/bulge extremes.
    static let deviationScale: Float = 0.04

    private static let carve = SIMD3<Float>(0.22, 0.38, 0.72)
    private static let neutral = SIMD3<Float>(0.78, 0.66, 0.50)
    private static let bulge = SIMD3<Float>(0.92, 0.42, 0.24)

    private static var cachedGradient: TextureResource?

    static func textureCoordinate(for position: SIMD3<Float>) -> SIMD2<Float> {
        let u = textureU(for: position)
        return SIMD2<Float>(u, 0.5)
    }

    static func gradientTexture() throws -> TextureResource {
        if let cachedGradient {
            return cachedGradient
        }

        let width = 256
        let height = 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for x in 0..<width {
            let u = Float(x) / Float(width - 1)
            let deviation = (u - 0.5) * 2 * deviationScale
            let rgb = rgb(deviation: deviation)
            let r = UInt8(max(0, min(255, Int(rgb.x * 255))))
            let g = UInt8(max(0, min(255, Int(rgb.y * 255))))
            let b = UInt8(max(0, min(255, Int(rgb.z * 255))))
            for y in 0..<height {
                let index = (y * width + x) * 4
                pixels[index] = r
                pixels[index + 1] = g
                pixels[index + 2] = b
                pixels[index + 3] = 255
            }
        }

        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            throw GradientTextureError.providerFailed
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw GradientTextureError.imageFailed
        }

        let texture = try TextureResource.generate(
            from: cgImage,
            options: TextureResource.CreateOptions(semantic: .color)
        )
        cachedGradient = texture
        return texture
    }

    private static func textureU(for position: SIMD3<Float>) -> Float {
        let deviation = simd_length(position) - baseRadius
        return max(0, min(1, 0.5 + deviation / (2 * deviationScale)))
    }

    private static func rgb(deviation: Float) -> SIMD3<Float> {
        let t = max(-1, min(1, deviation / deviationScale))
        if t < 0 {
            return mix(neutral, carve, (-t))
        }
        return mix(neutral, bulge, t)
    }

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }

    private enum GradientTextureError: Error {
        case providerFailed
        case imageFailed
    }
}
