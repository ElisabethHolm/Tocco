import ARKit
import CoreGraphics
import UIKit

/// Builds a tinted person-segmentation debug image aligned to the ARView viewport.
enum PersonSegmentationOverlayProcessor {
    private static var lastRun: CFAbsoluteTime = 0
    private static let minInterval: CFAbsoluteTime = 1.0 / 12.0

    static func makeOverlayImage(
        from frame: ARFrame,
        viewSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> CGImage? {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastRun >= minInterval else { return nil }
        lastRun = now

        guard let segmentation = frame.segmentationBuffer else { return nil }
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }

        let width = CVPixelBufferGetWidth(segmentation)
        let height = CVPixelBufferGetHeight(segmentation)
        guard width > 0, height > 0 else { return nil }

        let viewW = Int(viewSize.width.rounded())
        let viewH = Int(viewSize.height.rounded())
        guard viewW > 0, viewH > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: viewW,
            height: viewH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: viewW, height: viewH))
        // CGContext uses a bottom-left origin; flip so we can draw in UIKit top-left coordinates.
        ctx.translateBy(x: 0, y: CGFloat(viewH))
        ctx.scaleBy(x: 1, y: -1)

        CVPixelBufferLockBaseAddress(segmentation, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(segmentation, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(segmentation) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(segmentation)

        let personFill = UIColor.systemGreen.withAlphaComponent(0.42).cgColor
        let block: CGFloat = 3
        let step = 2

        for sy in stride(from: 0, to: height, by: step) {
            for sx in stride(from: 0, to: width, by: step) {
                let value = base.load(fromByteOffset: sy * bytesPerRow + sx, as: UInt8.self)
                guard value > 127 else { continue }

                let viewPoint = ARCameraOverlayMapper.bufferPixelToView(
                    x: sx,
                    y: sy,
                    bufferWidth: width,
                    bufferHeight: height,
                    frame: frame,
                    viewSize: viewSize,
                    orientation: orientation
                )

                ctx.setFillColor(personFill)
                ctx.fill(CGRect(
                    x: viewPoint.x - block * 0.5,
                    y: viewPoint.y - block * 0.5,
                    width: block,
                    height: block
                ))
            }
        }

        return ctx.makeImage()
    }
}
