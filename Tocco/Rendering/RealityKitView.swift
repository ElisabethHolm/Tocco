import ARKit
import Combine
import RealityKit
import SwiftUI

struct RealityKitView: UIViewRepresentable {
    private static var makeUIViewCount = 0

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var arSessionManager: ARSessionManager
    @EnvironmentObject private var sculptEngine: SculptEngine
    @EnvironmentObject private var commandStack: CommandStack
    @StateObject private var handRecognizer = HandGestureRecognizer()
    private let gestureRouter = GestureShortcutRouter()

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ARView {
        ToccoDebug.logConsoleNoiseHint()
        let arView = ARView(frame: .zero)
        arSessionManager.configure(session: arView.session)

        let sculptMesh = SculptMeshEntity(meshData: sculptEngine.meshData)

        Self.makeUIViewCount += 1
        ToccoDebug.info(
            "ARView",
            "makeUIView #\(Self.makeUIViewCount) — clay mesh ready (\(sculptEngine.meshData.vertices.count) vertices); will anchor ~0.65m in front of camera on first AR frame"
        )

        context.coordinator.configure(arView: arView, meshEntity: sculptMesh)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.handRecognizer = handRecognizer
        context.coordinator.refreshMesh(meshData: sculptEngine.meshData)
        context.coordinator.syncInteractionMode(appState.mode)
        context.coordinator.applyTransform(
            scale: appState.modelScale,
            rotationY: appState.modelRotationY,
            yOffset: appState.modelYOffset
        )

        let frameMS = context.coordinator.lastFrameMS
        let vertexCount = sculptEngine.meshData.vertices.count
        let brushMS = sculptEngine.lastBrushTimeMS
        let nextSample = PerformanceSample(
            frameTimeMS: frameMS,
            vertexCount: vertexCount,
            brushTimeMS: brushMS
        )

        DispatchQueue.main.async {
            if appState.useHandGestures {
                gestureRouter.apply(handRecognizer, to: appState)
            }
            if nextSample != appState.performanceSample {
                appState.performanceSample = nextSample
            }
        }
    }

    final class Coordinator: NSObject {
        private let parent: RealityKitView
        private var arView: ARView?
        private var meshEntity: SculptMeshEntity?
        private var didPlaceClayAnchor = false
        private var touchController: TouchSculptController?
        private var cancellables = Set<AnyCancellable>()
        private var gesture: UIPanGestureRecognizer?
        private var manipulationGestures: [UIGestureRecognizer] = []
        private let visionHandPipeline = VisionHandPipeline()
        var handRecognizer: HandGestureRecognizer?
        private(set) var lastFrameMS: Double = 0
        private var lastFrameTime = CACurrentMediaTime()

        init(parent: RealityKitView) {
            self.parent = parent
            super.init()
        }

        func configure(arView: ARView, meshEntity: SculptMeshEntity) {
            self.arView = arView
            self.meshEntity = meshEntity
            self.touchController = TouchSculptController(
                arView: arView,
                appState: parent.appState,
                sculptEngine: parent.sculptEngine,
                commandStack: parent.commandStack
            )
            self.touchController?.sculptTarget = meshEntity.modelEntity

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            arView.addGestureRecognizer(pan)
            self.gesture = pan
            self.manipulationGestures = arView.installGestures([.rotation, .translation, .scale], for: meshEntity.modelEntity)
            syncInteractionMode(parent.appState.mode)

            arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                guard let self else { return }
                self.placeClayAnchorIfNeeded()

                let gesturesOn = self.parent.appState.useHandGestures
                if let ar = self.arView, let hr = self.handRecognizer {
                    self.visionHandPipeline.processFrame(arView: ar, handRecognizer: hr, enabled: gesturesOn)
                    self.refreshAimAssist(arView: ar, handRecognizer: hr)
                    if gesturesOn, self.parent.appState.mode == .sculpt, hr.currentGesture == .pinch {
                        let aim = hr.pinchAimViewPoint ?? hr.indexTipViewPoint
                        if let p = aim {
                            self.touchController?.sculpt(at: p)
                        }
                    }
                }

                let now = CACurrentMediaTime()
                self.lastFrameMS = (now - self.lastFrameTime) * 1000
                self.lastFrameTime = now
            }
            .store(in: &cancellables)
        }

        /// Updates thumb/index markers, reticle, and projected camera ray (normalized UV). Touch-only path leaves reticle/ray to `TouchSculptController`.
        private func refreshAimAssist(arView: ARView, handRecognizer: HandGestureRecognizer) {
            let appState = parent.appState
            guard let modelEntity = meshEntity?.modelEntity else { return }
            let sz = arView.bounds.size
            let w = max(sz.width, 1)
            let h = max(sz.height, 1)
            func norm(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / w, y: p.y / h) }

            DispatchQueue.main.async {
                guard appState.showAimAssist else {
                    appState.thumbTipUV = nil
                    appState.indexTipUV = nil
                    appState.aimReticleUV = nil
                    appState.aimReticleHitsClay = false
                    appState.aimRayPolylineUV = []
                    return
                }

                if appState.useHandGestures {
                    appState.thumbTipUV = handRecognizer.thumbTipViewPoint.map(norm)
                    appState.indexTipUV = handRecognizer.indexTipViewPoint.map(norm)

                    let aimPoint: CGPoint?
                    if handRecognizer.currentGesture == .pinch {
                        aimPoint = handRecognizer.pinchAimViewPoint ?? handRecognizer.indexTipViewPoint
                    } else {
                        aimPoint = handRecognizer.indexTipViewPoint
                    }

                    if let p = aimPoint {
                        appState.aimReticleUV = norm(p)
                        appState.aimReticleHitsClay = ClayScreenRay.screenAimHitsClay(
                            screenPoint: p,
                            arView: arView,
                            modelEntity: modelEntity
                        )
                        let poly = AimRayProjection.screenRayPolyline(screenPoint: p, arView: arView)
                        appState.aimRayPolylineUV = poly.map(norm)
                    } else {
                        appState.aimReticleUV = nil
                        appState.aimReticleHitsClay = false
                        appState.aimRayPolylineUV = []
                    }
                } else {
                    appState.thumbTipUV = nil
                    appState.indexTipUV = nil
                }
            }
        }

        private func placeClayAnchorIfNeeded() {
            guard !didPlaceClayAnchor, let arView, let meshEntity else { return }
            guard let frame = arView.session.currentFrame else { return }

            didPlaceClayAnchor = true

            var offset = matrix_identity_float4x4
            offset.columns.3 = SIMD4<Float>(0, -0.05, -0.65, 1)

            let world4x4 = simd_mul(frame.camera.transform, offset)
            let anchor = AnchorEntity(world: world4x4)

            let light = DirectionalLight()
            light.light.intensity = 3500
            light.orientation = simd_quatf(angle: -Float.pi / 5, axis: SIMD3<Float>(1, 0, 0))
            anchor.addChild(light)

            anchor.addChild(meshEntity.modelEntity)
            arView.scene.addAnchor(anchor)

            ToccoDebug.info(
                "ARView",
                "Placed clay sphere anchor ~0.65m forward, slightly below camera center (vertices=\(parent.sculptEngine.meshData.vertices.count))"
            )
        }

        func refreshMesh(meshData: MeshData) {
            meshEntity?.update(meshData: meshData)
        }

        func applyTransform(scale: Float, rotationY: Float, yOffset: Float) {
            guard let entity = meshEntity?.modelEntity else { return }
            entity.scale = SIMD3<Float>(repeating: max(0.2, min(3, scale)))
            entity.orientation = simd_quatf(angle: rotationY, axis: SIMD3<Float>(0, 1, 0))
            entity.position.y = yOffset
        }

        func syncInteractionMode(_ mode: InteractionMode) {
            let sculptEnabled = mode == .sculpt
            gesture?.isEnabled = sculptEnabled
            manipulationGestures.forEach { $0.isEnabled = !sculptEnabled }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.appState.mode == .sculpt else { return }
            guard let arView else { return }
            let point = gesture.location(in: arView)

            switch gesture.state {
            case .began:
                ToccoDebug.info("Input", "Pan began (sculpt) at screen (\(Int(point.x)),\(Int(point.y)))")
            case .ended, .cancelled, .failed:
                ToccoDebug.info("Input", "Pan ended state=\(gesture.state.rawValue)")
                if !parent.appState.useHandGestures {
                    DispatchQueue.main.async {
                        let s = self.parent.appState
                        guard s.showAimAssist else { return }
                        s.aimReticleUV = nil
                        s.aimReticleHitsClay = false
                        s.aimRayPolylineUV = []
                    }
                }
            default:
                break
            }

            if gesture.state == .began || gesture.state == .changed {
                touchController?.sculpt(at: point)
            }
        }
    }
}
