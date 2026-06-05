import SwiftUI

struct ToolPanelView: View {
    var maxExpandedHeight: CGFloat = 420

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sculptEngine: SculptEngine
    @EnvironmentObject private var commandStack: CommandStack
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.toolPanelExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Tocco")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(appState.toolPanelExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: appState.toolPanelExpanded)
                }
            }
            .buttonStyle(.plain)

            if appState.toolPanelExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    controlsContent
                }
                .frame(maxHeight: maxExpandedHeight)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(InteractionMode.allCases) { mode in
                    Button {
                        appState.mode = mode
                    } label: {
                        Label(mode.clayName, systemImage: mode.clayIcon)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.mode == mode ? .accentColor : .gray.opacity(0.35))
                }
            }

            Text(appState.mode.clayHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if appState.mode == .sculpt {
                if appState.useHandGestures {
                    Label(appState.selectedTool.clayName, systemImage: appState.selectedTool.clayIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(SculptTool.allCases) { tool in
                            Button {
                                appState.selectedTool = tool
                            } label: {
                                Label(tool.clayName, systemImage: tool.clayIcon)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(appState.selectedTool == tool ? .accentColor : .secondary)
                        }
                    }
                    Text("Turn on “Use your hands” to sculpt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if appState.mode == .sculpt {
                VStack(alignment: .leading) {
                    Text("Hand size")
                    Slider(value: $appState.brushSize, in: 0.01...0.2)
                }
                VStack(alignment: .leading) {
                    Text("Pressure")
                    Slider(value: $appState.brushStrength, in: 0.002...0.08)
                }
            } else {
                VStack(alignment: .leading) {
                    Text("Piece size")
                    Slider(value: $appState.modelScale, in: 0.2...3.0)
                }
            }

            Toggle("Use your hands", isOn: $appState.useHandGestures)
            Toggle("Aim guide", isOn: $appState.showAimAssist)

            DisclosureGroup("Debug") {
                Toggle("Hand skeleton", isOn: $appState.showHandSkeletonOverlay)
                Toggle("Person mask", isOn: $appState.showPersonSegmentationOverlay)
            }

            HStack {
                Button("Undo") {
                    var copy = sculptEngine.meshData
                    commandStack.undo(on: &copy)
                    sculptEngine.restore(meshData: copy)
                }.disabled(!commandStack.canUndo)

                Button("Redo") {
                    var copy = sculptEngine.meshData
                    commandStack.redo(on: &copy)
                    sculptEngine.restore(meshData: copy)
                }.disabled(!commandStack.canRedo)
            }

            HStack {
                Button("Reset clay") {
                    sculptEngine.resetMesh()
                    commandStack.reset()
                }

                Button("Save") {
                    try? sessionStore.save(meshData: sculptEngine.meshData)
                }

                Button("Load") {
                    if let mesh = try? sessionStore.load() {
                        sculptEngine.restore(meshData: mesh)
                    }
                }
            }

            Button("Export OBJ") {
                try? OBJExporter().export(meshData: sculptEngine.meshData)
            }
        }
    }
}
