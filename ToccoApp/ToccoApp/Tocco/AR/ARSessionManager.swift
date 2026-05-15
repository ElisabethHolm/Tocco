import ARKit
import Combine
import Foundation

final class ARSessionManager: NSObject, ObservableObject {
    @Published private(set) var sessionState: SessionState = .idle
    /// SwiftUI can call `makeUIView` more than once; avoid double `run` on the same session.
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
        // Lighter than `.automatic`; reduces GPU/memory pressure on device.
        configuration.environmentTexturing = .none
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration)
        ToccoDebug.info("ARSession", "session.run(configuration) called — planeDetection=horizontal+vertical, environmentTexturing=none")
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .running
            ToccoDebug.info("ARSession", "sessionState → running (published async)")
        }
    }
}
