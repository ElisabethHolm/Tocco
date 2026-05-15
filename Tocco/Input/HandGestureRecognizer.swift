import ARKit
import Combine
import CoreGraphics
import Foundation
import UIKit
import Vision

final class HandGestureRecognizer: ObservableObject {
    @Published private(set) var confidence: Float = 0
    @Published private(set) var currentGesture: Gesture = .none
    @Published private(set) var indexTipViewPoint: CGPoint?
    @Published private(set) var thumbTipViewPoint: CGPoint?
    @Published private(set) var pinchAimViewPoint: CGPoint?

    enum Gesture: String {
        case none
        case pinch
        case openPalm
        case fist
    }

    func clearVision() {
        confidence = 0
        currentGesture = .none
        indexTipViewPoint = nil
        thumbTipViewPoint = nil
        pinchAimViewPoint = nil
    }

    func applyVisionObservation(
        _ observation: VNHumanHandPoseObservation?,
        arFrame: ARFrame,
        viewBounds: CGRect,
        interfaceOrientation: UIInterfaceOrientation
    ) {
        guard let observation, observation.confidence > 0.25 else {
            clearVision()
            return
        }

        confidence = Float(observation.confidence)

        guard let thumb = try? observation.recognizedPoint(.thumbTip),
              let index = try? observation.recognizedPoint(.indexTip),
              thumb.confidence > 0.2, index.confidence > 0.2 else {
            currentGesture = .none
            indexTipViewPoint = nil
            thumbTipViewPoint = nil
            pinchAimViewPoint = nil
            return
        }

        let thumbP = thumb.location
        let indexP = index.location
        let pinchDist = hypot(Float(thumbP.x - indexP.x), Float(thumbP.y - indexP.y))

        if pinchDist < 0.11 {
            currentGesture = .pinch
        } else if pinchDist > 0.30 {
            currentGesture = classifyOpenOrFist(observation)
        } else {
            currentGesture = .none
        }

        let thumbView = mapVisionPointToView(
            normalizedVision: thumbP,
            frame: arFrame,
            viewBounds: viewBounds,
            interfaceOrientation: interfaceOrientation
        )
        let indexView = mapVisionPointToView(
            normalizedVision: indexP,
            frame: arFrame,
            viewBounds: viewBounds,
            interfaceOrientation: interfaceOrientation
        )
        indexTipViewPoint = indexView
        thumbTipViewPoint = thumbView

        if currentGesture == .pinch {
            let mid = CGPoint(x: (thumbView.x + indexView.x) / 2, y: (thumbView.y + indexView.y) / 2)
            pinchAimViewPoint = mid.clamped(to: viewBounds.insetBy(dx: -20, dy: -20))
        } else {
            pinchAimViewPoint = nil
        }
    }

    private func classifyOpenOrFist(_ observation: VNHumanHandPoseObservation) -> Gesture {
        guard let wrist = try? observation.recognizedPoint(.wrist), wrist.confidence > 0.2 else {
            return .openPalm
        }
        let tips: [VNHumanHandPoseObservation.JointName] = [.indexTip, .middleTip, .ringTip, .littleTip]
        var sumDist: Float = 0
        var count = 0
        for joint in tips {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.15 else { continue }
            sumDist += hypot(Float(p.x - wrist.location.x), Float(p.y - wrist.location.y))
            count += 1
        }
        guard count > 0 else { return .openPalm }
        let avg = sumDist / Float(count)
        return avg < 0.17 ? .fist : .openPalm
    }

    private func mapVisionPointToView(
        normalizedVision: CGPoint,
        frame: ARFrame,
        viewBounds: CGRect,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGPoint {
        let n = normalizedVision
        let t = frame.displayTransform(for: interfaceOrientation, viewportSize: viewBounds.size)
        let viewNormalized = n.applying(t)
        let raw = CGPoint(
            x: viewNormalized.x * viewBounds.width,
            y: viewNormalized.y * viewBounds.height
        )
        return raw.clamped(to: viewBounds.insetBy(dx: -40, dy: -40))
    }
}

private extension CGPoint {
    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(x, rect.minX), rect.maxX),
            y: min(max(y, rect.minY), rect.maxY)
        )
    }
}
