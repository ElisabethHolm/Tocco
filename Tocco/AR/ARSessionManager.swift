import ARKit
import Combine
import Foundation

final class ARSessionManager: NSObject, ObservableObject {
    @Published private(set) var sessionState: SessionState = .idle
    private weak var configuredSession: ARSession?

    enum SessionState {
        case idle
        case running
        case failed(String)
    }

    func configure(session: ARSession) {
        if configuredSession === session {
            ToccoDebug.throttled(
                "ar-configure-skip",
                interval: 4,
                category: "ARSession",
                "configure skipped — already applied to this ARSession (duplicate makeUIView)"
            )
            return
        }
        if configuredSession != nil {
            ToccoDebug.warn(
                "ARSession",
                "configure for a new ARSession (SwiftUI rebuilt ARView). Previous camera session replaced."
            )
        }
        configuredSession = session

        ToccoDebug.info("ARSession", "configure(session:) — worldTrackingSupported=\(ARWorldTrackingConfiguration.isSupported)")
        guard ARWorldTrackingConfiguration.isSupported else {
            ToccoDebug.error("ARSession", "World tracking not supported on this device.")
            DispatchQueue.main.async { [weak self] in
                self?.sessionState = .failed("World tracking is unavailable on this device.")
            }
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .none
        configuration.planeDetection = [.horizontal, .vertical]
        let occlusionSummary = Self.applyOcclusion(to: configuration)
        session.run(configuration)
        ToccoDebug.info(
            "ARSession",
            "session.run(configuration) — planeDetection=horizontal+vertical, environmentTexturing=none, occlusion=[\(occlusionSummary)]"
        )
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .running
            ToccoDebug.info("ARSession", "sessionState → running (published async)")
        }
    }

    /// Enables real-world depth occlusion so hands (and body) can cover virtual clay when closer to the camera.
    /// People occlusion is automatic in ARView once `personSegmentationWithDepth` is set.
    /// LiDAR environment mesh occlusion requires `sceneUnderstanding.options` on the ARView as well.
    static func applyOcclusion(to configuration: ARWorldTrackingConfiguration) -> String {
        var enabled: [String] = []

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
            enabled.append("people+depth")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
            enabled.append("people")
        }

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            enabled.append("environment-mesh")
        }

        return enabled.isEmpty ? "unsupported" : enabled.joined(separator: ", ")
    }

    static var supportsEnvironmentMeshOcclusion: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
}
