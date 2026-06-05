import CoreGraphics
import Vision

enum HandSkeleton {
    /// Vision hand-pose bones in MediaPipe-style connectivity.
    static let bonePairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
        (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP),
    ]

    static let orderedJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    static func extract(
        from observation: VNHumanHandPoseObservation,
        mapPoint: (CGPoint) -> CGPoint
    ) -> (segments: [(CGPoint, CGPoint)], joints: [CGPoint]) {
        func viewPoint(for joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.12 else { return nil }
            return mapPoint(p.location)
        }

        var segments: [(CGPoint, CGPoint)] = []
        for (a, b) in bonePairs {
            guard let start = viewPoint(for: a), let end = viewPoint(for: b) else { continue }
            segments.append((start, end))
        }

        let joints = orderedJoints.compactMap { viewPoint(for: $0) }
        return (segments, joints)
    }
}
