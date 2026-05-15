# Tocco

Organic 3D AR sculpting prototype for iPhone/iPad using SwiftUI, ARKit, RealityKit, and a lightweight mesh deformation engine.

## Current MVP

- Anchored AR clay mesh (sphere) rendered in `RealityKit`.
- Touch-based sculpting (`push`, `pull`, `smooth`) with brush size and strength controls.
- Undo/redo command stack for reversible deformation.
- Performance overlay with frame time, brush op time, and vertex count.
- Navigate mode for scale/rotation/height transform controls.
- Session save/load to app Documents directory.
- OBJ export implemented.
- glTF export path stubbed with stable API for future full buffer/accessor output.

## Project Layout

- `Tocco/App`: App lifecycle and root view.
- `Tocco/AR`: AR session configuration.
- `Tocco/Rendering`: RealityKit integration and mesh entity updates.
- `Tocco/Sculpt`: Mesh data, brush kernels, local normal updates, command stack.
- `Tocco/Input`: Touch sculpt controller and gesture shortcut routing scaffold.
- `Tocco/UI`: Tool panel and live performance overlay.
- `Tocco/Export`: OBJ/glTF export modules.
- `Tocco/Session`: Save/load session serialization.
- `ToccoTests`: Unit tests for sculpt invariants and undo/redo behavior.

## Running In Xcode

1. Open the folder in Xcode and create an iOS App target named `Tocco` if needed.
2. Include all source files under `Tocco/`.
3. Enable camera usage in app privacy descriptions (`NSCameraUsageDescription`).
4. Run on a physical iPhone/iPad (AR is not supported in Simulator).

## Testing

- Preferred: run unit tests via Xcode (`Product > Test` / `Cmd+U`).
- Terminal runner (simulator):
  - `scripts/test_ios.sh`
  - or `scripts/test_ios.sh Tocco "platform=iOS Simulator,name=iPhone 15"`
- Note: `swift test` is not the right entry point for this app-level target because core modules reference iOS-only frameworks.

## Validation Checklist

- Sculpting keeps mesh valid (no NaN vertices).
- Undo/redo cycles restore/reapply deformation.
- Frame timing stays interactive under normal brush usage.
- Exported `.obj` opens correctly in Blender or another 3D tool.

## Next Stretch Work

- Vision-based hand gesture pipeline with camera frame processing.
- Confidence-weighted gesture shortcuts with robust false-positive handling.
- Full glTF exporter with binary buffers and material support.
- Optional adaptive remeshing for higher-detail sculpt zones.