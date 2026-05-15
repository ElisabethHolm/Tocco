import Foundation

/// Applies Vision-derived shortcuts only on gesture **edges** so the brush picker is not overwritten every frame.
final class GestureShortcutRouter {
    /// Vision observation confidence for palm/fist shortcuts only (pinch sets Pull independently).
    private let threshold: Float = 0.4
    private let pinchDoubleTapWindow: TimeInterval = 0.55

    func apply(_ recognizer: HandGestureRecognizer, to appState: AppState) {
        guard appState.useHandGestures else {
            appState.lastHandShortcutGesture = .none
            appState.lastPinchShortcutTimestamp = nil
            return
        }

        let g = recognizer.currentGesture
        let prev = appState.lastHandShortcutGesture

        if g == .pinch {
            if prev != .pinch {
                let now = ProcessInfo.processInfo.systemUptime
                if let lastPinch = appState.lastPinchShortcutTimestamp, now - lastPinch <= pinchDoubleTapWindow {
                    appState.mode = appState.mode == .sculpt ? .navigate : .sculpt
                    appState.statusText = appState.mode == .sculpt
                        ? "Gesture: Sculpt mode"
                        : "Gesture: Move mode (rotate, translate, scale)"
                    appState.lastPinchShortcutTimestamp = nil
                    appState.lastHandShortcutGesture = .pinch
                    return
                }
                appState.lastPinchShortcutTimestamp = now
                appState.selectedTool = .pull
                appState.statusText = "Gesture: Pull (pinch sculpt)"
            }
            appState.lastHandShortcutGesture = .pinch
            return
        }

        guard recognizer.confidence >= threshold else {
            appState.statusText = "Low hand confidence — shortcuts paused"
            appState.lastHandShortcutGesture = g
            return
        }

        // Skip prev == .none so the first camera frame doesn't override the brush you picked in the UI.
        if g == .openPalm, prev != .openPalm, prev != .none {
            appState.selectedTool = .smooth
            appState.statusText = "Gesture: Smooth"
        } else if g == .fist, prev != .fist, prev != .none {
            appState.selectedTool = .push
            appState.statusText = "Gesture: Push"
        }

        appState.lastHandShortcutGesture = g
    }
}
