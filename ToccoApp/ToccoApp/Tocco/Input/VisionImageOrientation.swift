import UIKit
import ImageIO

/// Maps UI orientation to `CGImagePropertyOrientation` for **rear** camera buffers used with ARKit + Vision.
/// Keeps `VNImageRequestHandler` and `ARFrame.displayTransform` consistent for the same `UIInterfaceOrientation`.
extension UIInterfaceOrientation {
    var cgImagePropertyOrientationForBackCamera: CGImagePropertyOrientation {
        switch self {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        default: return .right
        }
    }
}
