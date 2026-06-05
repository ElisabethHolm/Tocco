import ARKit
import CoreGraphics
import UIKit

/// Maps Vision / camera-buffer coordinates into ARView UIKit overlay space (top-left origin, points).
enum ARCameraOverlayMapper {
    /// Vision `VNRecognizedPoint.location` uses a lower-left origin in the **raw** `capturedImage` buffer.
    /// Route through the same buffer-pixel → view path used by the person-segmentation overlay.
    static func visionNormalizedToView(
        _ visionNormalized: CGPoint,
        frame: ARFrame,
        viewSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> CGPoint {
        let buffer = frame.capturedImage
        let bufferWidth = CVPixelBufferGetWidth(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)
        guard bufferWidth > 0, bufferHeight > 0 else { return .zero }

        let w = CGFloat(bufferWidth)
        let h = CGFloat(bufferHeight)
        let px = Int(min(max(visionNormalized.x * w, 0), w - 1))
        // Vision y=0 is buffer bottom; pixel row 0 is buffer top.
        let py = Int(min(max((1.0 - visionNormalized.y) * h, 0), h - 1))

        return bufferPixelToView(
            x: px,
            y: py,
            bufferWidth: bufferWidth,
            bufferHeight: bufferHeight,
            frame: frame,
            viewSize: viewSize,
            orientation: orientation
        )
    }

    /// Normalized pixel in `capturedImage` / `segmentationBuffer` (upper-left origin) → view point.
    static func bufferPixelToView(
        x: Int,
        y: Int,
        bufferWidth: Int,
        bufferHeight: Int,
        frame: ARFrame,
        viewSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> CGPoint {
        let imageNormalized = CGPoint(
            x: (CGFloat(x) + 0.5) / CGFloat(bufferWidth),
            y: (CGFloat(y) + 0.5) / CGFloat(bufferHeight)
        )
        return imageNormalizedToView(imageNormalized, frame: frame, viewSize: viewSize, orientation: orientation)
    }

    private static func imageNormalizedToView(
        _ imageNormalized: CGPoint,
        frame: ARFrame,
        viewSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> CGPoint {
        let transform = frame.displayTransform(for: orientation, viewportSize: viewSize)
        let viewNormalized = imageNormalized.applying(transform)
        return CGPoint(
            x: viewNormalized.x * viewSize.width,
            y: viewNormalized.y * viewSize.height
        )
    }
}
