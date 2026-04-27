import SwiftUI

struct AppShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .paperBackground()
                .ignoresSafeArea()

            HomeView(model: model)
        }
    }
}
