import Foundation

final class GestureShortcutRouter {
    private let toolCycleTapWindow: TimeInterval = 0.55
    private let toolCycleMinGap: TimeInterval = 0.12

    func apply(_ recognizer: HandGestureRecognizer, to appState: AppState) {
        guard appState.useHandGestures else {
            appState.lastHandShortcutGesture = .none
            appState.lastPinchShortcutTimestamp = nil
            return
        }

        let g = recognizer.currentGesture
        let prev = appState.lastHandShortcutGesture

        if g == .pinch {
            if prev != .pinch, !appState.aimReticleHitsClay {
                let now = ProcessInfo.processInfo.systemUptime
                if let lastPinch = appState.lastPinchShortcutTimestamp,
                   now - lastPinch <= toolCycleTapWindow,
                   now - lastPinch >= toolCycleMinGap {
                    cycleToNextTool(appState)
                    appState.lastPinchShortcutTimestamp = nil
                } else {
                    appState.lastPinchShortcutTimestamp = now
                }
            }
            appState.lastHandShortcutGesture = .pinch
            return
        }

        appState.lastHandShortcutGesture = g
    }

    private func cycleToNextTool(_ appState: AppState) {
        let next: SculptTool
        switch appState.selectedTool {
        case .pull: next = .push
        case .push: next = .smooth
        case .smooth: next = .pull
        }
        appState.selectedTool = next
        appState.presentGestureToast(next.clayName, symbol: next.clayIcon)
    }
}
