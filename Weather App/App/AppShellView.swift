import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppShellView: View {
    @Bindable var model: AppModel
    @State private var keepsLaunchOverlayVisible = true

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            HomeView(model: model)

            if shouldShowLaunchOverlay {
                AppLaunchView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            resolveLaunchOverlayVisibility()
        }
        .onChange(of: launchOverlayIsStillNeeded) { _, isNeeded in
            guard keepsLaunchOverlayVisible, !isNeeded else { return }

            withAnimation(.easeOut(duration: 0.24)) {
                keepsLaunchOverlayVisible = false
            }
        }
    }

    private var shouldShowLaunchOverlay: Bool {
        keepsLaunchOverlayVisible && launchOverlayIsStillNeeded
    }

    private var launchOverlayIsStillNeeded: Bool {
        if model.weatherState != nil {
            return false
        }

        if model.isBootstrapping || model.isWaitingForCurrentLocation {
            return true
        }

        return model.isRefreshing && model.placeSummaries.isEmpty
    }

    private func resolveLaunchOverlayVisibility() {
        guard keepsLaunchOverlayVisible, !launchOverlayIsStillNeeded else { return }
        keepsLaunchOverlayVisible = false
    }
}

private struct AppLaunchView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            Text("Wetterblatt")
                .font(DesignTokens.serif(size: 30, weight: .bold))
                .foregroundStyle(Color.primary)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
