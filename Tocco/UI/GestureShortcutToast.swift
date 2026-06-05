import SwiftUI

struct GestureShortcutToast: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack {
            Spacer()
            if let toast = appState.gestureToast {
                HStack(spacing: 8) {
                    if let symbol = toast.symbol {
                        Image(systemName: symbol)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.gestureToast)
        .allowsHitTesting(false)
    }
}
