import SwiftUI

struct PerformanceOverlay: View {
    @EnvironmentObject private var appState: AppState
    let sample: PerformanceSample

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.performancePanelExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Performance")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(appState.performancePanelExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            if appState.performancePanelExpanded {
                Text(String(format: "Frame %.1f ms", sample.frameTimeMS))
                Text(String(format: "Brush %.2f ms", sample.brushTimeMS))
                Text("Vertices \(sample.vertexCount)")
            }
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
