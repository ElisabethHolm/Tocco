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
        arView.automaticallyConfigureSession = false
        if ARSessionManager.supportsEnvironmentMeshOcclusion {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        }
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
        context.coordinator.syncTransformFromAppStateIfNeeded()

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
        private var didInstallManipulationGestures = false
        private var lastSyncedScale: Float = -1
        private var lastSyncedRotationY: Float = -999
        private var lastSyncedYOffset: Float = -999
        private var transformAxesGizmo: TransformAxesGizmo?
        private var draggingHandle: TransformAxesGizmo.HandleKind?
        private var lastGizmoDragPoint: CGPoint?
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
            syncInteractionMode(parent.appState.mode)

            arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                guard let self else { return }
                self.placeClayAnchorIfNeeded()

                let appState = self.parent.appState
                let gesturesOn = appState.useHandGestures
                let handTrackingOn = gesturesOn || appState.showHandSkeletonOverlay
                if let ar = self.arView, let hr = self.handRecognizer {
                    self.visionHandPipeline.processFrame(arView: ar, handRecognizer: hr, handTrackingEnabled: handTrackingOn)
                    self.refreshAimAssist(arView: ar, handRecognizer: hr)
                    self.refreshDebugOverlays(arView: ar, handRecognizer: hr)
                    if gesturesOn, appState.mode == .sculpt, hr.currentGesture == .pinch {
                        let aim = hr.pinchAimViewPoint ?? hr.indexTipViewPoint
                        if let p = aim {
                            self.touchController?.sculpt(at: p)
                        }
                    }
                }

                if let ar = self.arView {
                    self.refreshAxisGizmoLabels(arView: ar)
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
                appState.overlayViewportSize = sz

                guard appState.showAimAssist else {
                    appState.thumbTipUV = nil
                    appState.indexTipUV = nil
                    appState.aimReticleUV = nil
                    appState.aimReticleHitsClay = false
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
                    } else {
                        appState.aimReticleUV = nil
                        appState.aimReticleHitsClay = false
                    }
                } else {
                    appState.thumbTipUV = nil
                    appState.indexTipUV = nil
                }
            }
        }

        private func refreshDebugOverlays(arView: ARView, handRecognizer: HandGestureRecognizer) {
            let appState = parent.appState
            let sz = arView.bounds.size
            let w = max(sz.width, 1)
            let h = max(sz.height, 1)
            func norm(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / w, y: p.y / h) }

            let skeletonSegments = handRecognizer.skeletonSegmentViewPoints.map { (norm($0.0), norm($0.1)) }
            let skeletonJoints = handRecognizer.skeletonJointViewPoints.map(norm)

            let segmentationImage: CGImage?
            if appState.showPersonSegmentationOverlay, let frame = arView.session.currentFrame {
                let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
                segmentationImage = PersonSegmentationOverlayProcessor.makeOverlayImage(
                    from: frame,
                    viewSize: sz,
                    orientation: orientation
                )
            } else {
                segmentationImage = nil
            }

            DispatchQueue.main.async {
                appState.overlayViewportSize = sz

                if appState.showHandSkeletonOverlay {
                    appState.handSkeletonSegmentsUV = skeletonSegments
                    appState.handSkeletonJointUVs = skeletonJoints
                } else {
                    appState.handSkeletonSegmentsUV = []
                    appState.handSkeletonJointUVs = []
                }

                if appState.showPersonSegmentationOverlay {
                    if let segmentationImage {
                        appState.personSegmentationOverlayImage = segmentationImage
                    }
                } else {
                    appState.personSegmentationOverlayImage = nil
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

            let gizmo = TransformAxesGizmo()
            gizmo.attach(to: meshEntity.modelEntity)
            transformAxesGizmo = gizmo
            syncGizmoVisibility()

            arView.scene.addAnchor(anchor)
            installManipulationGesturesIfNeeded(on: arView)

            ToccoDebug.info(
                "ARView",
                "Placed clay sphere anchor ~0.65m forward, slightly below camera center (vertices=\(parent.sculptEngine.meshData.vertices.count))"
            )
        }

        private func installManipulationGesturesIfNeeded(on arView: ARView) {
            guard !didInstallManipulationGestures, let meshEntity else { return }
            let entity = meshEntity.modelEntity
            entity.generateCollisionShapes(recursive: true)
            manipulationGestures = arView.installGestures([.scale], for: entity)
            didInstallManipulationGestures = true
            syncInteractionMode(parent.appState.mode)
            ToccoDebug.info(
                "Input",
                "Installed manipulation gestures (rotate/scale) on clay — move mode uses RGB axis handles"
            )
        }

        func refreshMesh(meshData: MeshData) {
            meshEntity?.update(meshData: meshData)
        }

        func syncTransformFromAppStateIfNeeded() {
            let scale = parent.appState.modelScale
            let rotationY = parent.appState.modelRotationY
            let yOffset = parent.appState.modelYOffset
            guard
                scale != lastSyncedScale
                    || rotationY != lastSyncedRotationY
                    || yOffset != lastSyncedYOffset
            else { return }

            applyTransform(scale: scale, rotationY: rotationY, yOffset: yOffset)
            lastSyncedScale = scale
            lastSyncedRotationY = rotationY
            lastSyncedYOffset = yOffset
        }

        func applyTransform(scale: Float, rotationY: Float, yOffset: Float) {
            guard let entity = meshEntity?.modelEntity else { return }
            entity.scale = SIMD3<Float>(repeating: max(0.2, min(3, scale)))
            entity.orientation = simd_quatf(angle: rotationY, axis: SIMD3<Float>(0, 1, 0))
            entity.position.y = yOffset
        }

        func syncInteractionMode(_ mode: InteractionMode) {
            let sculptEnabled = mode == .sculpt
            gesture?.isEnabled = !sculptEnabled
            manipulationGestures.forEach { $0.isEnabled = !sculptEnabled }
            syncGizmoVisibility()
            if sculptEnabled {
                draggingHandle = nil
                lastGizmoDragPoint = nil
                transformAxesGizmo?.setSelected(nil)
            }
            ToccoDebug.throttled(
                "interaction-mode-\(mode.rawValue)",
                interval: 2,
                category: "Input",
                "mode=\(mode.rawValue) screenPan=\(!sculptEnabled) manipulationGestures=\(manipulationGestures.count) enabled=\(!sculptEnabled)"
            )
        }

        private func syncGizmoVisibility() {
            let show = parent.appState.mode == .navigate
            transformAxesGizmo?.setVisible(show)
            if !show {
                DispatchQueue.main.async {
                    self.parent.appState.axisGizmoLabels = []
                }
            }
        }

        private func refreshAxisGizmoLabels(arView: ARView) {
            guard parent.appState.mode == .navigate,
                  let gizmo = transformAxesGizmo,
                  let model = meshEntity?.modelEntity,
                  let frame = arView.session.currentFrame else {
                return
            }

            let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
            let viewport = arView.bounds.size
            guard viewport.width > 1, viewport.height > 1 else { return }

            var labels: [AxisGizmoLabel] = []

            for axis in TransformAxesGizmo.Axis.allCases {
                let color: Color
                switch axis {
                case .x: color = .red
                case .y: color = .green
                case .z: color = .blue
                }

                let moveTip = gizmo.moveTipWorldPosition(for: axis, on: model)
                let moveScreen = frame.camera.projectPoint(moveTip, orientation: orientation, viewportSize: viewport)
                let moveUV = CGPoint(x: moveScreen.x / viewport.width, y: moveScreen.y / viewport.height)
                if (0 ... 1).contains(moveUV.x), (0 ... 1).contains(moveUV.y) {
                    labels.append(AxisGizmoLabel(id: "move-\(axis.rawValue)", text: axis.moveLabel, uv: moveUV, color: color))
                }

                let ringPoint = gizmo.rotateLabelWorldPosition(for: axis, on: model)
                let ringScreen = frame.camera.projectPoint(ringPoint, orientation: orientation, viewportSize: viewport)
                let ringUV = CGPoint(x: ringScreen.x / viewport.width, y: ringScreen.y / viewport.height)
                if (0 ... 1).contains(ringUV.x), (0 ... 1).contains(ringUV.y) {
                    labels.append(AxisGizmoLabel(id: "rotate-\(axis.rawValue)", text: axis.rotateLabel, uv: ringUV, color: color.opacity(0.85)))
                }
            }

            DispatchQueue.main.async {
                self.parent.appState.axisGizmoLabels = labels
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.appState.mode == .navigate else { return }
            handleGizmoPan(gesture)
        }

        private func handleGizmoPan(_ gesture: UIPanGestureRecognizer) {
            guard let arView, let model = meshEntity?.modelEntity, let gizmo = transformAxesGizmo else { return }
            let point = gesture.location(in: arView)

            switch gesture.state {
            case .began:
                let hits = arView.hitTest(point, query: .nearest, mask: .all)
                if let hit = hits.first(where: { gizmo.handle(for: $0.entity) != nil }),
                   let handle = gizmo.handle(for: hit.entity) {
                    draggingHandle = handle
                    gizmo.setSelected(handle)
                    lastGizmoDragPoint = point
                    switch handle {
                    case .translate(let axis):
                        parent.appState.presentGestureToast("Slide \(axis.moveLabel)", symbol: "arrow.up.and.down.and.arrow.left.and.right")
                    case .rotate(let axis):
                        parent.appState.presentGestureToast("Turn \(axis.rotateLabel)", symbol: "rotate.3d")
                    }
                }
            case .changed:
                guard let handle = draggingHandle, let lastPoint = lastGizmoDragPoint else { return }
                let delta = CGPoint(x: point.x - lastPoint.x, y: point.y - lastPoint.y)
                lastGizmoDragPoint = point

                switch handle {
                case .translate(let axis):
                    applyGizmoTranslation(axis: axis, delta: delta, model: model, gizmo: gizmo, arView: arView)
                case .rotate(let axis):
                    applyGizmoRotation(axis: axis, point: point, lastPoint: lastPoint, model: model, gizmo: gizmo, arView: arView)
                }
            case .ended, .cancelled, .failed:
                draggingHandle = nil
                lastGizmoDragPoint = nil
                gizmo.setSelected(nil)
                syncAppStatePositionFromEntity()
            default:
                break
            }
        }

        private func applyGizmoTranslation(
            axis: TransformAxesGizmo.Axis,
            delta: CGPoint,
            model: ModelEntity,
            gizmo: TransformAxesGizmo,
            arView: ARView
        ) {
            guard let frame = arView.session.currentFrame else { return }
            let uiOrientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
            let viewport = arView.bounds.size
            let origin = model.position(relativeTo: nil)
            let tip = gizmo.moveTipWorldPosition(for: axis, on: model)
            let p0 = frame.camera.projectPoint(origin, orientation: uiOrientation, viewportSize: viewport)
            let p1 = frame.camera.projectPoint(tip, orientation: uiOrientation, viewportSize: viewport)
            var screenDir = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            let len = hypot(screenDir.x, screenDir.y)
            guard len > 2 else { return }
            screenDir.x /= len
            screenDir.y /= len

            let screenAmount = Float(delta.x * screenDir.x + delta.y * screenDir.y)
            let worldAxis = normalize(model.convert(direction: gizmo.localDirection(for: axis), to: nil))
            let move = worldAxis * screenAmount * 0.0025
            let localDelta = model.parent?.convert(direction: move, from: nil) ?? move
            model.position += localDelta
        }

        private func applyGizmoRotation(
            axis: TransformAxesGizmo.Axis,
            point: CGPoint,
            lastPoint: CGPoint,
            model: ModelEntity,
            gizmo: TransformAxesGizmo,
            arView: ARView
        ) {
            guard let frame = arView.session.currentFrame else { return }
            let uiOrientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
            let viewport = arView.bounds.size
            let centerWorld = model.position(relativeTo: nil)
            let centerScreen = frame.camera.projectPoint(centerWorld, orientation: uiOrientation, viewportSize: viewport)

            let a0 = atan2(Float(lastPoint.y - centerScreen.y), Float(lastPoint.x - centerScreen.x))
            let a1 = atan2(Float(point.y - centerScreen.y), Float(point.x - centerScreen.x))
            var delta = a1 - a0
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }

            let localAxis = normalize(gizmo.localDirection(for: axis))
            let parentAxis = normalize(model.parent?.convert(direction: localAxis, from: model) ?? localAxis)
            model.orientation = simd_quatf(angle: delta, axis: parentAxis) * model.orientation
        }

        private func syncAppStatePositionFromEntity() {
            guard let model = meshEntity?.modelEntity else { return }
            let y = model.position.y
            lastSyncedYOffset = y
            DispatchQueue.main.async {
                self.parent.appState.modelYOffset = y
            }
        }
    }
}
