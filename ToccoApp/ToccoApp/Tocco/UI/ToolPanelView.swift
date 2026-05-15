import SwiftUI

struct ToolPanelView: View {
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
                    Text("Sculpt controls")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(appState.toolPanelExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: appState.toolPanelExpanded)
                }
            }
            .buttonStyle(.plain)

            if appState.toolPanelExpanded {
                controlsContent
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $appState.mode) {
                ForEach(InteractionMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Brush", selection: $appState.selectedTool) {
                ForEach(SculptTool.allCases) { tool in
                    Text(tool.rawValue.capitalized).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading) {
                Text("Size \(appState.brushSize, specifier: "%.3f")")
                Slider(value: $appState.brushSize, in: 0.01...0.2)
            }

            VStack(alignment: .leading) {
                Text("Strength \(appState.brushStrength, specifier: "%.3f")")
                Slider(value: $appState.brushStrength, in: 0.002...0.08)
            }

            Toggle("Enable Hand Gestures", isOn: $appState.useHandGestures)
            Toggle("Aim assist (reticle)", isOn: $appState.showAimAssist)
            Text("Pinch near the camera to sculpt (index aim). Double-pinch quickly toggles Sculpt/Move mode. Open hand / fist change tool when confidence is high.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if appState.mode == .navigate {
                VStack(alignment: .leading) {
                    Text("Scale \(appState.modelScale, specifier: "%.2f")")
                    Slider(value: $appState.modelScale, in: 0.2...3.0)
                }
                VStack(alignment: .leading) {
                    Text("Rotate Y \(appState.modelRotationY, specifier: "%.2f")")
                    Slider(value: $appState.modelRotationY, in: -Float.pi...Float.pi)
                }
                VStack(alignment: .leading) {
                    Text("Lift \(appState.modelYOffset, specifier: "%.2f")")
                    Slider(value: $appState.modelYOffset, in: -0.3...0.3)
                }
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
                Button("Reset Mesh") {
                    sculptEngine.resetMesh()
                    commandStack.reset()
                }

                Button("Save") {
                    do {
                        try sessionStore.save(meshData: sculptEngine.meshData)
                    } catch {
                        ToccoDebug.error("Session", "Save failed: \(error.localizedDescription)")
                    }
                }

                Button("Load") {
                    do {
                        let mesh = try sessionStore.load()
                        sculptEngine.restore(meshData: mesh)
                    } catch {
                        ToccoDebug.error("Session", "Load failed: \(error.localizedDescription)")
                    }
                }
            }

            Button("Export OBJ") {
                do {
                    _ = try OBJExporter().export(meshData: sculptEngine.meshData)
                } catch {
                    ToccoDebug.error("Export", "OBJ export failed: \(error.localizedDescription)")
                }
            }

            Button("Export glTF (stub)") {
                do {
                    _ = try GLTFExporter().exportStub(meshData: sculptEngine.meshData)
                } catch {
                    ToccoDebug.error("Export", "glTF stub export failed: \(error.localizedDescription)")
                }
            }

            Text(appState.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
