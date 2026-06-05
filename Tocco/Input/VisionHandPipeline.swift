import ARKit
import CoreGraphics
import Foundation
import RealityKit
import UIKit
import Vision

/// Runs Vision hand pose on the current AR camera frame (must run while `ARFrame` is valid — call from main).
final class VisionHandPipeline {
    private var lastRun: CFAbsoluteTime = 0
    private let minInterval: CFAbsoluteTime = 1.0 / 24.0

    func processFrame(arView: ARView, handRecognizer: HandGestureRecognizer, handTrackingEnabled: Bool) {
        guard handTrackingEnabled else {
            handRecognizer.clearVision()
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastRun >= minInterval else { return }
        lastRun = now

        guard let frame = arView.session.currentFrame else { return }
        let bounds = arView.bounds

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let uiOrientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        // Use `.up` so joint coordinates stay in the raw `capturedImage` buffer space (same as segmentation).
        // Passing a display orientation here yields upright-normalized points that do not match `displayTransform`.
        let handler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
            let observation = request.results?.first as? VNHumanHandPoseObservation
            handRecognizer.applyVisionObservation(
                observation,
                arFrame: frame,
                viewBounds: bounds,
                interfaceOrientation: uiOrientation
            )
        } catch {
            handRecognizer.clearVision()
        }
    }
}
