import SwiftUI

/// Tinted person-segmentation mask aligned to the camera feed (debug).
struct PersonSegmentationOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { _ in
            if appState.showPersonSegmentationOverlay, let image = appState.personSegmentationOverlayImage {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}
