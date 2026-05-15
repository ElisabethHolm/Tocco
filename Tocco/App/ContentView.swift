import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var arSessionManager = ARSessionManager()
    @StateObject private var sculptEngine = SculptEngine()
    @StateObject private var commandStack = CommandStack()
    @StateObject private var sessionStore = SessionStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityKitView()
                .environmentObject(appState)
                .environmentObject(arSessionManager)
                .environmentObject(sculptEngine)
                .environmentObject(commandStack)
                .environmentObject(sessionStore)
                .ignoresSafeArea()

            AimAssistOverlay()
                .environmentObject(appState)

            VStack(alignment: .leading, spacing: 12) {
                ToolPanelView()
                PerformanceOverlay(sample: appState.performanceSample)
            }
            .padding()
        }
        .environmentObject(sculptEngine)
        .environmentObject(commandStack)
        .environmentObject(sessionStore)
        .onAppear {
            ToccoDebug.logContentViewAppearOnce()
        }
    }
}
