# Tocco

**Tocco** is an iOS AR sculpting app that lets you shape virtual clay in your physical space using either touch or hand gestures. You can save your sculptures, return to them later, and export them as 3D meshes. Tocco was built as the final project for Stanford's CS 153: Frontier Systems.

---

## Overview

### Why Tocco?

Digital sculpting tools are powerful, but they often rely on desktops, styluses, and complex interfaces. Physical clay, on the other hand, is intuitive—you simply push, pull, and shape it with your hands—but it's messy, temporary, and difficult to share.

Tocco explores whether augmented reality can bring some of the natural feel of working with clay into a digital medium. Instead of sculpting on a screen, you place a virtual object in the real world, shape it in place, and keep or export the result when you're done.

### How It Works

Tocco combines:

- **ARKit** and **RealityKit** for world-anchored augmented reality
- A custom **mesh deformation engine** with push, pull, and smooth brushes
- **Vision-based hand tracking** for gesture-driven sculpting
- Traditional **touch controls** and transform tools for precise editing

The project started as a touch-based sculpting prototype and gradually evolved to include hand gestures, usability improvements, visual feedback, testing, and performance tooling.

### Features

- AR clay sphere anchored in the real world
- Three sculpting tools:
  - **Build** (pull outward)
  - **Carve** (push inward)
  - **Blend** (smooth surface)
- Touch-based sculpting
- Optional hand-gesture sculpting with aim assist
- Double-pinch gesture to cycle between tools
- Separate **Shape** and **Move** modes
- Undo and redo support
- Save and load sessions
- OBJ mesh export
- Performance metrics overlay
- Debug views for hand tracking and person segmentation

### Current Limitations

- Hand-gesture sculpting can be sensitive to lighting, distance, and camera positioning.
- A physical iPhone or iPad is required; the iOS Simulator cannot provide the full AR experience.
- glTF export is not yet implemented; OBJ export is currently the supported workflow.
- Mesh resolution is fixed and does not support adaptive remeshing.

---

## Setup

### Requirements

- Mac with **Xcode** installed
- Physical **iPhone or iPad** with a rear camera
- Apple developer signing configured for your device

### Build and Run

1. Clone the repository.
2. Open `ToccoApp/ToccoApp.xcodeproj` in Xcode.
3. Select a physical device as the run destination.
4. Build and run (`⌘R`).

The app will request camera access when launched.

### Running Tests

- Sculpting engine tests are located in `ToccoTests/` and can be run with `⌘U`.
- AR functionality and hand-tracking interactions must be tested on a physical device.
- See `docs/UserTestingProtocol.md` for the usability testing procedure.

---

## Using Tocco

1. Launch the app and allow camera access.
2. Point the device at a flat surface until the clay sphere appears.
3. In **Shape Mode**:
   - Sculpt using touch input, or enable **Use Your Hands** for gesture-based sculpting.
   - Adjust brush size and pressure as needed.
   - Double-pinch in the air to switch between Build, Carve, and Blend.
   - Surface colors indicate deformation depth:
     - Blue = carved inward
     - Tan = unchanged
     - Orange = built outward
4. Switch to **Move Mode** to scale, rotate, or raise the sculpture.
5. Use **Undo** and **Redo** to reverse edits.
6. Save or load projects from local storage.
7. Export completed sculptures as OBJ files for use in Blender or other 3D software.

Optional debugging tools include an aim guide, hand-skeleton visualization, and person-segmentation overlays.

---

## Evaluation

| Area | Validation |
|--------|------------|
| Correctness | Unit tests verify brush behavior, prevent invalid geometry, and validate undo/redo functionality. |
| Performance | Real-time overlays display frame timing, brush execution time, and vertex counts. |
| Usability | User studies measure task completion, accidental edits, performance, and subjective feedback. |
| Export | Generated OBJ files were successfully imported into external 3D tools such as Blender. |
| Iteration | Development progressed from a basic sculpting prototype to gesture controls and usability improvements. |

---

## AI Usage Disclosure

AI coding assistants, including **Cursor**, **Claude**, and **GPT-based models**, were used throughout development for:

- Generating boilerplate code and project scaffolding
- Debugging ARKit and Vision integration issues
- Refactoring code and exploring implementation approaches
- Assisting with documentation and writing

All final design decisions, implementation choices, testing, and evaluation were performed by the project author. AI-generated suggestions were reviewed, modified, and validated before being incorporated into the project.

---

## Acknowledgements

- **Course:** CS 153 – Frontier Systems, Stanford University
- **Author:** Elisabeth Holm
- Built from scratch specifically for this project
- Uses Apple's ARKit, RealityKit, Vision, and SwiftUI frameworks

Tocco was inspired by the tactile experience of working with real clay and by the potential of mobile AR as a creative medium. The goal was not to replace professional 3D modeling software, but to create a lightweight, intuitive sculpting experience that feels natural and approachable.

---

## External Resources

- ARKit Documentation
- RealityKit Documentation
- Vision Hand Pose Detection
- Vision Person Segmentation
- Wavefront OBJ Specification
- Blender

---

## Project Structure

| Path | Description |
|------|-------------|
| `ToccoApp/ToccoApp/` | Main iOS application target |
| `Tocco/` | Shared package source code |
| `Tocco/App` | App lifecycle and root views |
| `Tocco/AR` | AR session setup and management |
| `Tocco/Rendering` | Mesh rendering, coloring, and transform controls |
| `Tocco/Sculpt` | Mesh data structures, brush operations, and undo/redo |
| `Tocco/Input` | Touch input, hand tracking, and gesture recognition |
| `Tocco/UI` | User interface panels and overlays |
| `Tocco/Export` | OBJ export functionality |
| `Tocco/Session` | Save/load serialization |
| `ToccoTests/` | Unit tests |
| `docs/` | User testing materials |
| `scripts/` | Test and utility scripts |